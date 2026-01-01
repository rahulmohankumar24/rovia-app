import SwiftUI

// MARK: - Rovia Design System
// Warm cream backgrounds, soft sage green accents
// Calm, meditation-app aesthetic

struct Theme {
    // MARK: - Colors
    struct Colors {
        // Backgrounds
        static let background = Color(hex: "FAF9F7")
        static let card = Color(hex: "FDFCFB")
        static let cardAlt = Color(hex: "F7F5F2")

        // Text
        static let foreground = Color(hex: "3D3834")
        static let mutedForeground = Color(hex: "7A746D")

        // Primary - Sage Green
        static let primary = Color(hex: "4A9B5C")
        static let primaryLight = Color(hex: "5AAF6C")
        static let primaryDark = Color(hex: "3A8B4C")
        static let primaryForeground = Color(hex: "FDFCFB")

        // Secondary
        static let secondary = Color(hex: "F5F3F0")
        static let secondaryForeground = Color(hex: "4A4540")

        // Muted
        static let muted = Color(hex: "F0EEEA")
        static let mutedDark = Color(hex: "E8E5E0")

        // Macro colors
        static let protein = Color(hex: "3B82F6")
        static let carbs = Color(hex: "F59E0B")
        static let fat = Color(hex: "EF4444")
        static let calories = Color(hex: "4A9B5C")

        // Status colors
        static let success = Color(hex: "22C55E")
        static let warning = Color(hex: "F59E0B")
        static let error = Color(hex: "EF4444")
        static let info = Color(hex: "3B82F6")

        // Borders
        static let border = Color(hex: "E3E0DB")
        static let borderLight = Color(hex: "ECEAE6")
        static let input = Color(hex: "EBE8E4")

        // Destructive
        static let destructive = Color(hex: "C4735A")
        static let destructiveForeground = Color(hex: "FDFCFB")
    }

    // MARK: - Typography
    struct Typography {
        static let xs: CGFloat = 11
        static let sm: CGFloat = 13
        static let base: CGFloat = 15
        static let lg: CGFloat = 17
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 28
        static let display: CGFloat = 32
    }

    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    // MARK: - Border Radius
    struct Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Card Style Modifier
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.Colors.card)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
