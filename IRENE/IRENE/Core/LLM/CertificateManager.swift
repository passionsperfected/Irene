import Foundation
import Security

enum CertificateError: Error, LocalizedError {
    case fileNotFound(String)
    case invalidCertificate
    case invalidPrivateKey(String)
    case identityCreationFailed
    case keystoreError(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path): return "Certificate file not found: \(path)"
        case .invalidCertificate: return "Failed to parse certificate from PEM file"
        case .invalidPrivateKey(let r): return "Failed to parse private key: \(r)"
        case .identityCreationFailed: return "Failed to create identity from certificate and key"
        case .keystoreError(let m): return "Keystore error: \(m)"
        }
    }
}

@Observable @MainActor
final class CertificateManager {
    var isConfigured = false
    var error: String?

    private var identity: SecIdentity?
    private var certificate: SecCertificate?

    func configure(chainPath: String, privatePath: String) throws {
        Log.info("Configuring certificates")

        guard FileManager.default.fileExists(atPath: chainPath) else {
            throw CertificateError.fileNotFound(chainPath)
        }
        guard FileManager.default.fileExists(atPath: privatePath) else {
            throw CertificateError.fileNotFound(privatePath)
        }

        let chainData = try Data(contentsOf: URL(fileURLWithPath: chainPath))
        let privateData = try Data(contentsOf: URL(fileURLWithPath: privatePath))

        let certDER = try parseCertificatePEM(chainData)
        guard let cert = SecCertificateCreateWithData(nil, certDER as CFData) else {
            throw CertificateError.invalidCertificate
        }
        certificate = cert

        let privateKey = try importPrivateKey(from: privateData)
        try createIdentity(certificate: cert, privateKey: privateKey)

        isConfigured = true
        error = nil
        Log.info("Certificates configured successfully")
    }

    private func parseCertificatePEM(_ pemData: Data) throws -> Data {
        guard let pemString = String(data: pemData, encoding: .utf8) else {
            throw CertificateError.invalidCertificate
        }
        guard let begin = pemString.range(of: "-----BEGIN CERTIFICATE-----"),
              let end = pemString.range(of: "-----END CERTIFICATE-----") else {
            throw CertificateError.invalidCertificate
        }
        let base64 = String(pemString[begin.upperBound..<end.lowerBound])
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard let der = Data(base64Encoded: base64) else {
            throw CertificateError.invalidCertificate
        }
        return der
    }

    private func importPrivateKey(from pemData: Data) throws -> SecKey {
        var items: CFArray?
        var inputFormat = SecExternalFormat.formatPEMSequence
        var itemType = SecExternalItemType.itemTypePrivateKey
        var importParams = SecItemImportExportKeyParameters()

        var status = SecItemImport(
            pemData as CFData,
            "pem" as CFString,
            &inputFormat,
            &itemType,
            [],
            &importParams,
            nil,
            &items
        )

        if status == errSecSuccess, let arr = items as? [Any], let key = arr.first {
            Log.info("Imported private key via SecItemImport (PEM)")
            return key as! SecKey
        }

        Log.info("PEM import failed (\(status)), trying auto-detect")
        inputFormat = SecExternalFormat.formatUnknown
        status = SecItemImport(
            pemData as CFData,
            nil,
            &inputFormat,
            &itemType,
            [],
            &importParams,
            nil,
            &items
        )
        if status == errSecSuccess, let arr = items as? [Any], let key = arr.first {
            Log.info("Imported private key via SecItemImport (auto)")
            return key as! SecKey
        }

        Log.info("Auto-detect failed (\(status)), trying DER extraction")

        guard let pemString = String(data: pemData, encoding: .utf8) else {
            throw CertificateError.invalidPrivateKey("Could not read PEM data as string")
        }

        let formats = [
            ("-----BEGIN PRIVATE KEY-----", "-----END PRIVATE KEY-----"),
            ("-----BEGIN RSA PRIVATE KEY-----", "-----END RSA PRIVATE KEY-----")
        ]

        var derData: Data?
        var isPKCS8 = false

        for (index, (begin, end)) in formats.enumerated() {
            if let beginRange = pemString.range(of: begin),
               let endRange = pemString.range(of: end) {
                let base64 = String(pemString[beginRange.upperBound..<endRange.lowerBound])
                    .replacingOccurrences(of: "\n", with: "")
                    .replacingOccurrences(of: "\r", with: "")
                    .trimmingCharacters(in: .whitespaces)
                derData = Data(base64Encoded: base64)
                isPKCS8 = (index == 0)
                break
            }
        }

        guard let keyData = derData else {
            throw CertificateError.invalidPrivateKey("Could not find or decode PEM content")
        }

        if isPKCS8 {
            Log.info("Detected PKCS#8, extracting RSA key")
            if let rsa = try? extractRSAKeyFromPKCS8(keyData) {
                return rsa
            }
        }

        let attrs: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate
        ]
        var cfError: Unmanaged<CFError>?
        if let key = SecKeyCreateWithData(keyData as CFData, attrs as CFDictionary, &cfError) {
            Log.info("Created key via SecKeyCreateWithData")
            return key
        }
        let desc = cfError?.takeRetainedValue().localizedDescription ?? "Unknown error"
        throw CertificateError.invalidPrivateKey("All import methods failed. Last error: \(desc)")
    }

    /// PKCS#8: SEQUENCE { INTEGER (version), SEQUENCE { OID, NULL }, OCTET STRING (RSA key) }
    private func extractRSAKeyFromPKCS8(_ pkcs8Data: Data) throws -> SecKey {
        let bytes = [UInt8](pkcs8Data)
        guard bytes.count > 26 else {
            throw CertificateError.invalidPrivateKey("PKCS#8 data too short")
        }

        var index = 0
        guard bytes[index] == 0x30 else {
            throw CertificateError.invalidPrivateKey("Expected SEQUENCE")
        }
        index += 1
        index += getLengthBytes(bytes, at: index).bytesConsumed

        guard bytes[index] == 0x02 else {
            throw CertificateError.invalidPrivateKey("Expected INTEGER (version)")
        }
        index += 1
        let versionLen = getLengthBytes(bytes, at: index)
        index += versionLen.bytesConsumed + versionLen.length

        guard bytes[index] == 0x30 else {
            throw CertificateError.invalidPrivateKey("Expected SEQUENCE (algorithm)")
        }
        index += 1
        let algLen = getLengthBytes(bytes, at: index)
        index += algLen.bytesConsumed + algLen.length

        guard bytes[index] == 0x04 else {
            throw CertificateError.invalidPrivateKey("Expected OCTET STRING")
        }
        index += 1
        let keyLen = getLengthBytes(bytes, at: index)
        index += keyLen.bytesConsumed

        let rsaKeyData = Data(bytes[index..<(index + keyLen.length)])

        let attrs: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate
        ]
        var cfError: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(rsaKeyData as CFData, attrs as CFDictionary, &cfError) else {
            let desc = cfError?.takeRetainedValue().localizedDescription ?? "Unknown error"
            throw CertificateError.invalidPrivateKey("Failed RSA from PKCS#8: \(desc)")
        }
        return key
    }

    private func getLengthBytes(_ bytes: [UInt8], at index: Int) -> (length: Int, bytesConsumed: Int) {
        let firstByte = bytes[index]
        if firstByte < 0x80 {
            return (Int(firstByte), 1)
        }
        let numLengthBytes = Int(firstByte & 0x7F)
        var length = 0
        for i in 0..<numLengthBytes {
            length = (length << 8) | Int(bytes[index + 1 + i])
        }
        return (length, 1 + numLengthBytes)
    }

    private func createIdentity(certificate: SecCertificate, privateKey: SecKey) throws {
        let certAddQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: certificate,
            kSecAttrLabel as String: "IRENE-Temp-Cert"
        ]
        SecItemDelete(certAddQuery as CFDictionary)

        var status = SecItemAdd(certAddQuery as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            throw CertificateError.keystoreError("Failed to add certificate: \(status)")
        }

        let keyAddQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecValueRef as String: privateKey,
            kSecAttrLabel as String: "IRENE-Temp-Key",
            kSecAttrApplicationTag as String: "com.passionsperfected.irene.key".data(using: .utf8)!
        ]
        SecItemDelete(keyAddQuery as CFDictionary)
        status = SecItemAdd(keyAddQuery as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            throw CertificateError.keystoreError("Failed to add private key: \(status)")
        }

        let identityQuery: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var identityRef: CFTypeRef?
        status = SecItemCopyMatching(identityQuery as CFDictionary, &identityRef)
        guard status == errSecSuccess, let ref = identityRef else {
            throw CertificateError.identityCreationFailed
        }
        self.identity = (ref as! SecIdentity)
    }

    func createURLSession() -> URLSession? {
        guard isConfigured else { return nil }
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 180
        config.timeoutIntervalForResource = 300
        let delegate = URLSessionClientCertDelegate(identity: identity, certificate: certificate)
        return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }
}

final class URLSessionClientCertDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let identity: SecIdentity?
    private let certificate: SecCertificate?

    init(identity: SecIdentity?, certificate: SecCertificate?) {
        self.identity = identity
        self.certificate = certificate
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
            if let identity {
                let credential = URLCredential(
                    identity: identity,
                    certificates: certificate.map { [$0] },
                    persistence: .forSession
                )
                completionHandler(.useCredential, credential)
            } else {
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
        } else if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
