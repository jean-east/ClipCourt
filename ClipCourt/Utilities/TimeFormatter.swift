// TimeFormatter.swift
// ClipCourt
//
// Formats seconds into human-readable time strings.
// "I'm a unitard!" — but these are FORMATTED units.

import Foundation

enum TimeFormatter {

    // MARK: - Formatting

    /// Formats seconds as MM:SS or H:MM:SS for display.
    /// Examples: 65.3 → "1:05", 3661.7 → "1:01:01"
    static func format(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }

        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    /// Formats seconds with fractional precision: MM:SS.f
    /// Example: 65.3 → "1:05.3"
    static func formatPrecise(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00.0" }

        let totalSeconds = Int(seconds)
        let fraction = Int((seconds - Double(totalSeconds)) * 10)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d.%d", hours, minutes, secs, fraction)
        } else {
            return String(format: "%d:%02d.%d", minutes, secs, fraction)
        }
    }

    /// Formats a duration as a compact string: "2m 30s" or "1h 5m"
    static func formatCompact(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0s" }

        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else if minutes > 0 {
            return secs > 0 ? "\(minutes)m \(secs)s" : "\(minutes)m"
        } else {
            return "\(secs)s"
        }
    }
}
