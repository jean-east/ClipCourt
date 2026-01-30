// ExportViewModel.swift
// ClipCourt
//
// Orchestrates the export flow: settings selection, progress tracking,
// and saving to Photos. "The doctor said I wouldn't have so many
// nosebleeds if I kept my finger outta there." — The doctor also said
// use async/await for export pipelines.

import AVFoundation
import Observation
import SwiftUI

// MARK: - Export State

enum ExportState: Equatable {
    case idle
    case exporting
    case completed
    case failed(String)
}

// MARK: - ViewModel

@Observable
@MainActor
final class ExportViewModel {

    // MARK: - State

    var settings: ExportSettings = .default
    var state: ExportState = .idle
    var progress: Double = 0
    var showExportSheet: Bool = false

    // MARK: - Services

    private let exportService: ExportService

    // MARK: - Private

    private var exportTask: Task<Void, Never>?

    // MARK: - Init

    init(exportService: ExportService = ExportService()) {
        self.exportService = exportService
    }

    // MARK: - Computed

    var isExporting: Bool {
        state == .exporting
    }

    var canExport: Bool {
        state != .exporting
    }

    // MARK: - Export

    /// Start the export pipeline with the given asset and segments.
    func startExport(asset: AVAsset?, segments: [Segment]) {
        guard let asset else {
            state = .failed("No video loaded")
            return
        }

        let includedSegments = segments.filter(\.isIncluded)
        guard !includedSegments.isEmpty else {
            state = .failed("No segments marked for inclusion")
            return
        }

        state = .exporting
        progress = 0

        exportTask = Task { [weak self] in
            guard let self else { return }

            do {
                let outputURL: URL

                switch settings.mode {
                case .lossless:
                    outputURL = try await exportService.exportLossless(
                        asset: asset,
                        segments: includedSegments
                    )
                case .lossy:
                    outputURL = try await exportService.exportLossy(
                        asset: asset,
                        segments: includedSegments,
                        settings: settings
                    )
                }

                // Save to photo library
                try await exportService.saveToPhotoLibrary(url: outputURL)

                await MainActor.run {
                    self.state = .completed
                    self.progress = 1.0
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.state = .idle
                    self.progress = 0
                }
            } catch {
                await MainActor.run {
                    self.state = .failed(error.localizedDescription)
                }
            }
        }

        // Poll progress from service
        Task {
            while state == .exporting {
                progress = exportService.progress
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    /// Cancel an in-progress export.
    func cancelExport() {
        exportTask?.cancel()
        exportService.cancelExport()
        state = .idle
        progress = 0
    }

    /// Reset state after viewing completion/error.
    func reset() {
        state = .idle
        progress = 0
        settings = .default
    }
}
