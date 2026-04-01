import SwiftUI

struct VaultPickerView: View {
    let vaultManager: VaultManager
    let onComplete: () -> Void

    @Environment(\.ireneTheme) private var theme
    @State private var showFilePicker = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo area
            VStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 64, weight: .thin))
                    .foregroundStyle(theme.accent)

                Text("IRENE")
                    .font(Typography.heading(size: 36))
                    .foregroundStyle(theme.primaryText)

                Text("Intelligent Reasoning Engine\n& Natural Engagement")
                    .font(Typography.subheading(size: 16))
                    .foregroundStyle(theme.secondaryText)
                    .multilineTextAlignment(.center)
            }

            // Vault selection
            VStack(spacing: 16) {
                Text("Choose a Vault Location")
                    .font(Typography.bodySemiBold(size: 16))
                    .foregroundStyle(theme.primaryText)

                Text("IRENE stores your notes, conversations, and recordings as plain files in a vault folder. For syncing across devices, choose a location in iCloud Drive.")
                    .font(Typography.body(size: 13))
                    .foregroundStyle(theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)

                Button {
                    showFilePicker = true
                } label: {
                    Label("Select Vault Folder", systemImage: "folder.badge.plus")
                        .font(Typography.button(size: 14))
                        .textCase(.uppercase)
                        .tracking(1)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(theme.accent)
                        .foregroundStyle(theme.isDark ? Color.black : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                if let errorMessage {
                    Text(errorMessage)
                        .font(Typography.body(size: 12))
                        .foregroundStyle(.red)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFolderSelection(result)
        }
    }

    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                do {
                    try await vaultManager.setVault(url: url)
                    onComplete()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}
