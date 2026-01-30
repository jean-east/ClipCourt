// TimeFormatter.swift
// ClipCourt
//
// Formats seconds into human-readable time strings.
// "I'm a unitard!" — but these are FORMATTED units of time.

import Foundation

enum TimeFormatter {

    // MARK: - Standard Format (MM:SS or H:MM:SS)

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

    // MARK: - Precise Format (MM:SS.f — tenths)

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

    // MARK: - Milliseconds Format (MM:SS.mmm)

    /// Formats seconds with millisecond precision: MM:SS.mmm or H:MM:SS.mmm
    /// Example: 65.347 → "1:05.347", 3661.5 → "1:01:01.500"
    static func formatMilliseconds(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00.000" }

        let totalSeconds = Int(seconds)
        let millis = Int((seconds - Double(totalSeconds)) * 1000)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d.%03d", hours, minutes, secs, millis)
        } else {
            return String(format: "%d:%02d.%03d", minutes, secs, millis)
        }
    }

    // MARK: - Compact Format (2m 30s)

    /// Formats a duration as a compact string: "2m 30s" or "1h 5m"
    static func formatCompact(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0s" }

        let totalSeconds = Int(seconds)

        guard totalSeconds > 0 else { return "0s" }

        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(hours)h"
        } else if minutes > 0 {
            if secs > 0 {
                return "\(minutes)m \(secs)s"
            }
            return "\(minutes)m"
        } else {
            return "\(secs)s"
        }
    }

    // MARK: - Padded Format (00:00 or 00:00:00)

    /// Always zero-padded: "01:05" or "01:01:01". Useful for fixed-width displays.
    static func formatPadded(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "00:00" }

        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}
