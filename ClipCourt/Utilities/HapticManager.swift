// HapticManager.swift
// ClipCourt
//
// Centralized haptic feedback matching Design.md haptic palette.
// "I sleep in a drawer!" — and my haptics live in a manager.

import UIKit

enum HapticManager {

    // MARK: - Toggle

    /// Toggle ON: medium impact + 50ms + light impact (double-tap feel)
    static func toggleOn() {
        let medium = UIImpactFeedbackGenerator(style: .medium)
        medium.prepare()
        medium.impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let light = UIImpactFeedbackGenerator(style: .light)
            light.impactOccurred()
        }
    }

    /// Toggle OFF: single light impact (asymmetric — ON feels weightier)
    static func toggleOff() {
        let light = UIImpactFeedbackGenerator(style: .light)
        light.prepare()
        light.impactOccurred()
    }

    // MARK: - Playback

    /// Play/Pause: subtle selection changed
    static func playPause() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// Speed change: subtle selection changed
    static func speedChange() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// Skip forward/back: light impact
    static func skip() {
        let light = UIImpactFeedbackGenerator(style: .light)
        light.impactOccurred()
    }

    // MARK: - Fast Forward

    /// FF engage: rigid impact
    static func fastForwardEngage() {
        let rigid = UIImpactFeedbackGenerator(style: .rigid)
        rigid.prepare()
        rigid.impactOccurred()
    }

    /// FF release: soft impact
    static func fastForwardRelease() {
        let soft = UIImpactFeedbackGenerator(style: .soft)
        soft.impactOccurred()
    }

    // MARK: - Export

    /// Export button tap: medium impact
    static func exportTap() {
        let medium = UIImpactFeedbackGenerator(style: .medium)
        medium.impactOccurred()
    }

    /// Export complete: success notification
    static func exportComplete() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Timeline

    /// Segment tap on timeline: light impact
    static func segmentTap() {
        let light = UIImpactFeedbackGenerator(style: .light)
        light.impactOccurred()
    }

    /// Selection changed (for scrub bar, speed picker)
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
