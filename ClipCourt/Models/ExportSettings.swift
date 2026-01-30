// ExportSettings.swift
// ClipCourt
//
// Configuration for video export — lossless passthrough or lossy re-encode.
// "My cat's breath smells like cat food." — and my exports smell like
// PRISTINE MPEG-4 containers.

import Foundation

struct ExportSettings: Codable, Equatable {

    // MARK: - Export Mode

    enum ExportMode: String, Codable, CaseIterable, Identifiable {
        case lossless       // AVAssetExportSession passthrough — fast, keyframe-aligned
        case lossy          // AVAssetReader + AVAssetWriter — frame-accurate, smaller

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .lossless: "Original Quality"
            case .lossy:    "Smaller File (Re-encoded)"
            }
        }

        var subtitle: String {
            switch self {
            case .lossless: "Fast export, no quality loss"
            case .lossy:    "Frame-accurate cuts, smaller size"
            }
        }

        var iconName: String {
            switch self {
            case .lossless: "star.fill"
            case .lossy:    "bolt.fill"
            }
        }
    }

    // MARK: - Properties

    var mode: ExportMode
    var outputQuality: Double       // 0.0–1.0, applies only to lossy mode

    // MARK: - Defaults

    static let `default` = ExportSettings(
        mode: .lossless,
        outputQuality: 0.8
    )

    static let highQualityLossy = ExportSettings(
        mode: .lossy,
        outputQuality: 0.9
    )

    static let smallFileLossy = ExportSettings(
        mode: .lossy,
        outputQuality: 0.5
    )

    // MARK: - Initializer

    init(mode: ExportMode = .lossless, outputQuality: Double = 0.8) {
        self.mode = mode
        self.outputQuality = min(1.0, max(0.0, outputQuality))
    }
}
