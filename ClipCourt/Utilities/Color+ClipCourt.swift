// Color+ClipCourt.swift
// ClipCourt
//
// ──────────────────────────────────────────────
// SINGLE SOURCE OF TRUTH for all app colors.
// Every view should reference these tokens — never raw Color literals.
//
// Light/dark infrastructure is wired up via UIColor { traitCollection in … }.
// For now, BOTH branches return the dark palette so the app looks identical
// in either mode. To add a real light theme, swap in new values under .light.
// ──────────────────────────────────────────────
//
// "I picked these colors with my eyes!" — Ralph Wiggum, Color Theorist.

import SwiftUI

extension Color {

    // MARK: - Backgrounds

    /// #0A0A0F  Midnight
    static let ccBackground = Color(UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .light:
            return UIColor(red: 10/255, green: 10/255, blue: 15/255, alpha: 1) // TODO: light palette
        default:
            return UIColor(red: 10/255, green: 10/255, blue: 15/255, alpha: 1) // #0A0A0F Midnight
        }
    })

    /// #1A1A24  Charcoal
    static let ccSurface = Color(UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .light:
            return UIColor(red: 26/255, green: 26/255, blue: 36/255, alpha: 1) // TODO: light palette
        default:
            return UIColor(red: 26/255, green: 26/255, blue: 36/255, alpha: 1) // #1A1A24 Charcoal
        }
    })

    /// #252533  Slate
    static let ccSurfaceElevated = Color(UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .light:
            return UIColor(red: 37/255, green: 37/255, blue: 51/255, alpha: 1) // TODO: light palette
        default:
            return UIColor(red: 37/255, green: 37/255, blue: 51/255, alpha: 1) // #252533 Slate
        }
    })

    // MARK: - Text

    /// #F2F2F7  Snow
    static let ccTextPrimary = Color(UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .light:
            return UIColor(red: 242/255, green: 242/255, blue: 247/255, alpha: 1) // TODO: light palette
        default:
            return UIColor(red: 242/255, green: 242/255, blue: 247/255, alpha: 1) // #F2F2F7 Snow
        }
    })

    /// #8E8E93  Mist
    static let ccTextSecondary = Color(UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .light:
            return UIColor(red: 142/255, green: 142/255, blue: 147/255, alpha: 1) // TODO: light palette
        default:
            return UIColor(red: 142/255, green: 142/255, blue: 147/255, alpha: 1) // #8E8E93 Mist
        }
    })

    /// #48484A  Ash
    static let ccTextTertiary = Color(UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .light:
            return UIColor(red: 72/255, green: 72/255, blue: 74/255, alpha: 1) // TODO: light palette
        default:
            return UIColor(red: 72/255, green: 72/255, blue: 74/255, alpha: 1) // #48484A Ash
        }
    })

    // MARK: - Accent / Include

    /// #30D158  Rally Green
    static let ccInclude = Color(UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .light:
            return UIColor(red: 48/255, green: 209/255, blue: 88/255, alpha: 1) // TODO: light palette
        default:
            return UIColor(red: 48/255, green: 209/255, blue: 88/255, alpha: 1) // #30D158 Rally Green
        }
    })

    /// #34E060  Rally Glow
    static let ccIncludeGlow = Color(UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .light:
            return UIColor(red: 52/255, green: 224/255, blue: 96/255, alpha: 1) // TODO: light palette
        default:
            return UIColor(red: 52/255, green: 224/255, blue: 96/255, alpha: 1) // #34E060 Rally Glow
        }
    })

    // MARK: - Exclude

    /// #3A3A3C  Graphite
    static let ccExclude = Color(UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .light:
            return UIColor(red: 58/255, green: 58/255, blue: 60/255, alpha: 1) // TODO: light palette
        default:
            return UIColor(red: 58/255, green: 58/255, blue: 60/255, alpha: 1) // #3A3A3C Graphite
        }
    })

    // MARK: - Danger

    /// #FF453A  Court Red
    static let ccDanger = Color(UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .light:
            return UIColor(red: 255/255, green: 69/255, blue: 58/255, alpha: 1) // TODO: light palette
        default:
            return UIColor(red: 255/255, green: 69/255, blue: 58/255, alpha: 1) // #FF453A Court Red
        }
    })

    // MARK: - Export / Progress

    /// #0A84FF  Signal Blue
    static let ccExport = Color(UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .light:
            return UIColor(red: 10/255, green: 132/255, blue: 255/255, alpha: 1) // TODO: light palette
        default:
            return UIColor(red: 10/255, green: 132/255, blue: 255/255, alpha: 1) // #0A84FF Signal Blue
        }
    })

    // MARK: - Speed

    /// #FF9F0A  Fast Orange
    static let ccSpeed = Color(UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .light:
            return UIColor(red: 255/255, green: 159/255, blue: 10/255, alpha: 1) // TODO: light palette
        default:
            return UIColor(red: 255/255, green: 159/255, blue: 10/255, alpha: 1) // #FF9F0A Fast Orange
        }
    })
}
