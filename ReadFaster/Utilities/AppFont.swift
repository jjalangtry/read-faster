import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// Custom font definitions for the app.
/// Primary UI font: system default
/// Reading body serif: Averia Serif Libre
enum AppFont {
    static let familyName = "System"
    static let readingSerifFamilyName = "Averia Serif Libre"

    // MARK: - Font Weights

    static func light(size: CGFloat) -> Font {
        .system(size: size, weight: .light, design: .default)
    }

    static func regular(size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    static func medium(size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }

    static func semibold(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    static func bold(size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }

    // MARK: - Semantic Styles (matching system text styles)

    static var largeTitle: Font {
        .system(size: 34, weight: .bold, design: .default)
    }

    static var title: Font {
        .system(size: 28, weight: .semibold, design: .default)
    }

    static var title2: Font {
        .system(size: 22, weight: .semibold, design: .default)
    }

    static var title3: Font {
        .system(size: 20, weight: .medium, design: .default)
    }

    static var headline: Font {
        .system(size: 17, weight: .semibold, design: .default)
    }

    static var body: Font {
        .system(size: 17, weight: .regular, design: .default)
    }

    static var callout: Font {
        .system(size: 16, weight: .regular, design: .default)
    }

    static var subheadline: Font {
        .system(size: 15, weight: .regular, design: .default)
    }

    static var footnote: Font {
        .system(size: 13, weight: .regular, design: .default)
    }

    static var caption: Font {
        .system(size: 12, weight: .regular, design: .default)
    }

    static var caption2: Font {
        .system(size: 11, weight: .regular, design: .default)
    }

    // MARK: - RSVP Display

    static func rsvpWord(size: CGFloat) -> Font {
        .custom("AveriaSerifLibre-Regular", size: size)
    }

    /// Serif reserved for reading body text contexts.
    static func rsvpPhrase(size: CGFloat) -> Font {
        .custom("AveriaSerifLibre-Regular", size: size)
    }

    /// Serif reserved for reading body text contexts.
    static func contextWord(highlighted: Bool) -> Font {
        if highlighted {
            return .custom("AveriaSerifLibre-Bold", size: 16)
        } else {
            return .custom("AveriaSerifLibre-Regular", size: 16)
        }
    }

    // MARK: - UIFont/NSFont helpers

    #if canImport(UIKit)
    static func uiFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: weight)
    }
    #endif

    #if canImport(AppKit)
    static func nsFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        NSFont.systemFont(ofSize: size, weight: weight)
    }
    #endif
}

// MARK: - Global Font Modifier

/// Applies system typography defaults app-wide.
struct AppFontModifier: ViewModifier {
    init() {
        #if canImport(UIKit)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.titleTextAttributes = [.font: UIFont.systemFont(ofSize: 17, weight: .semibold)]
        appearance.largeTitleTextAttributes = [.font: UIFont.systemFont(ofSize: 34, weight: .bold)]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance

        UITabBarItem.appearance().setTitleTextAttributes(
            [.font: UIFont.systemFont(ofSize: 10, weight: .regular)],
            for: .normal
        )
        #endif
    }

    func body(content: Content) -> some View {
        content.font(AppFont.body)
    }
}

extension View {
    /// Applies the app typography defaults.
    func appFont() -> some View {
        self.modifier(AppFontModifier())
    }
}
