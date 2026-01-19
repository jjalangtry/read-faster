import SwiftUI

/// Custom font definitions for the app using Monaspace Xenon
enum AppFont {
    static let familyName = "Monaspace Xenon"
    
    // MARK: - Font Weights
    
    static func light(size: CGFloat) -> Font {
        .custom("MonaspaceXenon-Light", size: size)
    }
    
    static func regular(size: CGFloat) -> Font {
        .custom("MonaspaceXenon-Regular", size: size)
    }
    
    static func medium(size: CGFloat) -> Font {
        .custom("MonaspaceXenon-Medium", size: size)
    }
    
    static func semibold(size: CGFloat) -> Font {
        .custom("MonaspaceXenon-SemiBold", size: size)
    }
    
    static func bold(size: CGFloat) -> Font {
        .custom("MonaspaceXenon-Bold", size: size)
    }
    
    // MARK: - Semantic Styles (matching system text styles)
    
    static var largeTitle: Font {
        .custom("MonaspaceXenon-Bold", size: 34, relativeTo: .largeTitle)
    }
    
    static var title: Font {
        .custom("MonaspaceXenon-SemiBold", size: 28, relativeTo: .title)
    }
    
    static var title2: Font {
        .custom("MonaspaceXenon-SemiBold", size: 22, relativeTo: .title2)
    }
    
    static var title3: Font {
        .custom("MonaspaceXenon-Medium", size: 20, relativeTo: .title3)
    }
    
    static var headline: Font {
        .custom("MonaspaceXenon-SemiBold", size: 17, relativeTo: .headline)
    }
    
    static var body: Font {
        .custom("MonaspaceXenon-Regular", size: 17, relativeTo: .body)
    }
    
    static var callout: Font {
        .custom("MonaspaceXenon-Regular", size: 16, relativeTo: .callout)
    }
    
    static var subheadline: Font {
        .custom("MonaspaceXenon-Regular", size: 15, relativeTo: .subheadline)
    }
    
    static var footnote: Font {
        .custom("MonaspaceXenon-Regular", size: 13, relativeTo: .footnote)
    }
    
    static var caption: Font {
        .custom("MonaspaceXenon-Regular", size: 12, relativeTo: .caption)
    }
    
    static var caption2: Font {
        .custom("MonaspaceXenon-Regular", size: 11, relativeTo: .caption2)
    }
    
    // MARK: - RSVP Display
    
    static func rsvpWord(size: CGFloat) -> Font {
        .custom("MonaspaceXenon-Light", size: size)
    }
    
    static func contextWord(highlighted: Bool) -> Font {
        if highlighted {
            return .custom("MonaspaceXenon-SemiBold", size: 15, relativeTo: .subheadline)
        } else {
            return .custom("MonaspaceXenon-Regular", size: 15, relativeTo: .subheadline)
        }
    }
    
    // MARK: - UIFont for UIKit components
    
    #if canImport(UIKit)
    static func uiFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let fontName: String
        switch weight {
        case .light, .ultraLight, .thin:
            fontName = "MonaspaceXenon-Light"
        case .medium:
            fontName = "MonaspaceXenon-Medium"
        case .semibold:
            fontName = "MonaspaceXenon-SemiBold"
        case .bold, .heavy, .black:
            fontName = "MonaspaceXenon-Bold"
        default:
            fontName = "MonaspaceXenon-Regular"
        }
        return UIFont(name: fontName, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
    }
    #endif
    
    #if canImport(AppKit)
    static func nsFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let fontName: String
        switch weight {
        case .light, .ultraLight, .thin:
            fontName = "MonaspaceXenon-Light"
        case .medium:
            fontName = "MonaspaceXenon-Medium"
        case .semibold:
            fontName = "MonaspaceXenon-SemiBold"
        case .bold, .heavy, .black:
            fontName = "MonaspaceXenon-Bold"
        default:
            fontName = "MonaspaceXenon-Regular"
        }
        return NSFont(name: fontName, size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
    }
    #endif
}

// MARK: - Global Font Modifier

/// A view modifier that applies Monaspace Xenon as the default font throughout the view hierarchy
struct AppFontModifier: ViewModifier {
    init() {
        // Set UIKit appearance for navigation bars, etc.
        #if canImport(UIKit)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        
        // Title font
        if let titleFont = UIFont(name: "MonaspaceXenon-SemiBold", size: 17) {
            appearance.titleTextAttributes = [.font: titleFont]
        }
        
        // Large title font
        if let largeTitleFont = UIFont(name: "MonaspaceXenon-Bold", size: 34) {
            appearance.largeTitleTextAttributes = [.font: largeTitleFont]
        }
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Tab bar font
        if let tabFont = UIFont(name: "MonaspaceXenon-Regular", size: 10) {
            UITabBarItem.appearance().setTitleTextAttributes([.font: tabFont], for: .normal)
        }
        #endif
    }
    
    func body(content: Content) -> some View {
        content
            .font(AppFont.body)
    }
}

extension View {
    /// Applies the app's custom font (Monaspace Xenon) as the default font
    func appFont() -> some View {
        self.modifier(AppFontModifier())
    }
}
