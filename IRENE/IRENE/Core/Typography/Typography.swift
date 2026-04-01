import SwiftUI

enum Typography {
    // MARK: - Font Names

    private static let cinzelDecorativeRegular = "CinzelDecorative-Regular"
    private static let cinzelDecorativeBold = "CinzelDecorative-Bold"
    private static let cormorantRegular = "CormorantGaramond-Regular"
    private static let cormorantSemiBold = "CormorantGaramond-SemiBold"
    private static let cormorantItalic = "CormorantGaramond-Italic"
    private static let rajdhaniRegular = "Rajdhani-Regular"
    private static let rajdhaniMedium = "Rajdhani-Medium"
    private static let rajdhanSemiBold = "Rajdhani-SemiBold"
    private static let rajdhaniBold = "Rajdhani-Bold"

    // MARK: - Heading (Cinzel Decorative)

    static func heading(size: CGFloat = 28) -> Font {
        .custom(cinzelDecorativeBold, size: size)
    }

    static func headingRegular(size: CGFloat = 24) -> Font {
        .custom(cinzelDecorativeRegular, size: size)
    }

    // MARK: - Subheading (Cormorant Garamond)

    static func subheading(size: CGFloat = 18) -> Font {
        .custom(cormorantSemiBold, size: size)
    }

    static func subheadingRegular(size: CGFloat = 18) -> Font {
        .custom(cormorantRegular, size: size)
    }

    static func subheadingItalic(size: CGFloat = 18) -> Font {
        .custom(cormorantItalic, size: size)
    }

    // MARK: - Body (Rajdhani)

    static func body(size: CGFloat = 14) -> Font {
        .custom(rajdhaniRegular, size: size)
    }

    static func bodyMedium(size: CGFloat = 14) -> Font {
        .custom(rajdhaniMedium, size: size)
    }

    static func bodySemiBold(size: CGFloat = 14) -> Font {
        .custom(rajdhanSemiBold, size: size)
    }

    static func bodyBold(size: CGFloat = 14) -> Font {
        .custom(rajdhaniBold, size: size)
    }

    // MARK: - UI Elements

    static func button(size: CGFloat = 12) -> Font {
        .custom(rajdhanSemiBold, size: size)
    }

    static func caption(size: CGFloat = 10) -> Font {
        .custom(rajdhaniMedium, size: size)
    }

    static func label(size: CGFloat = 9) -> Font {
        .custom(rajdhanSemiBold, size: size)
    }

    // MARK: - Fallback System Fonts
    // Used when custom fonts aren't loaded (e.g., previews, tests)

    static func systemHeading(size: CGFloat = 28) -> Font {
        .system(size: size, weight: .bold, design: .serif)
    }

    static func systemBody(size: CGFloat = 14) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
}
