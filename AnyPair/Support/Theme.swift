import SwiftUI
import UIKit

enum AnyPairTheme {
    static let accent = Color(red: 0.23, green: 0.59, blue: 0.98)
    static let card = Color.white.opacity(0.08)
    static let cardStroke = Color.white.opacity(0.10)
    static let statusGood = Color(red: 0.30, green: 0.86, blue: 0.55)
    static let statusWarn = Color(red: 0.98, green: 0.78, blue: 0.28)
    static let statusBad = Color(red: 0.92, green: 0.32, blue: 0.36)
}

/// In-app language. `system` follows the iPhone's preferred language.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case arabic = "ar"
    case english = "en"

    static let defaultsKey = "anypair.language"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return tr("تلقائي (لغة الجهاز)", "Automatic (device language)")
        case .arabic: return "العربية"
        case .english: return "English"
        }
    }

    static var stored: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .system
    }

    static var layoutDirection: LayoutDirection { isArabic ? .rightToLeft : .leftToRight }

    /// Sheets, navigation bars and alerts are UIKit-backed and follow the iPhone's
    /// language, not the SwiftUI environment; force the in-app choice.
    static func applyToUIKit() {
        let attribute: UISemanticContentAttribute = isArabic ? .forceRightToLeft : .forceLeftToRight
        UIView.appearance().semanticContentAttribute = attribute
        UINavigationBar.appearance().semanticContentAttribute = attribute
    }

    static var isArabic: Bool {
        switch stored {
        case .arabic: return true
        case .english: return false
        case .system: return Locale.preferredLanguages.first?.hasPrefix("ar") ?? false
        }
    }
}

/// Returns the Arabic or English text for the current in-app language.
func tr(_ arabic: String, _ english: String) -> String {
    AppLanguage.isArabic ? arabic : english
}

extension View {
    /// Presented views do not reliably inherit the direction from the root.
    func appLayoutDirection() -> some View {
        environment(\.layoutDirection, AppLanguage.layoutDirection)
    }

    /// Rounded dark card used on every screen.
    func card(padding: CGFloat = 18) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AnyPairTheme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AnyPairTheme.cardStroke, lineWidth: 1))
    }
}

extension String {
    /// Keeps codes and identifiers in their own reading order inside Arabic text.
    var bidiIsolated: String { "\u{2068}" + self + "\u{2069}" }
}

/// Big capsule button like the home screen ones.
struct PillButtonStyle: ButtonStyle {
    var filled = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                Capsule().fill(filled ? AnyPairTheme.accent : AnyPairTheme.card)
            )
            .overlay(Capsule().stroke(AnyPairTheme.cardStroke, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Capsule())
    }
}
