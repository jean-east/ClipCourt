// Color+ClipCourt.swift
// ClipCourt
//
// Semantic color palette matching Design.md.
// "I picked these colors with my eyes!" — Ralph Wiggum, Color Theorist.

import SwiftUI

extension Color {
    // MARK: - Backgrounds
    static let ccBackground       = Color(red: 10/255, green: 10/255, blue: 15/255)        // #0A0A0F Midnight
    static let ccSurface          = Color(red: 26/255, green: 26/255, blue: 36/255)         // #1A1A24 Charcoal
    static let ccSurfaceElevated  = Color(red: 37/255, green: 37/255, blue: 51/255)         // #252533 Slate

    // MARK: - Text
    static let ccTextPrimary      = Color(red: 242/255, green: 242/255, blue: 247/255)      // #F2F2F7 Snow
    static let ccTextSecondary    = Color(red: 142/255, green: 142/255, blue: 147/255)      // #8E8E93 Mist
    static let ccTextTertiary     = Color(red: 72/255, green: 72/255, blue: 74/255)         // #48484A Ash

    // MARK: - Accent / Include
    static let ccInclude          = Color(red: 48/255, green: 209/255, blue: 88/255)        // #30D158 Rally Green
    static let ccIncludeGlow      = Color(red: 52/255, green: 224/255, blue: 96/255)        // #34E060 Rally Glow

    // MARK: - Exclude
    static let ccExclude          = Color(red: 58/255, green: 58/255, blue: 60/255)         // #3A3A3C Graphite

    // MARK: - Danger
    static let ccDanger           = Color(red: 255/255, green: 69/255, blue: 58/255)        // #FF453A Court Red

    // MARK: - Export / Progress
    static let ccExport           = Color(red: 10/255, green: 132/255, blue: 255/255)       // #0A84FF Signal Blue

    // MARK: - Speed
    static let ccSpeed            = Color(red: 255/255, green: 159/255, blue: 10/255)       // #FF9F0A Fast Orange
}
