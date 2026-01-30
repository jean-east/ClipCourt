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

    /// URL of the last successfully exported video (kept for sharing).
    var exportedFileURL: URL?

    // MARK: - Services

    private let exportService: ExportService

    // MARK: - Private

    private var exportTask: Task<Void, Never>?
    private var progressPollTask: Task<Void, Never>?

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

                // Clean up any prior share copies before creating a new one
                await self.cleanupStaleShareCopies()

                // Keep a copy for sharing before saving to Photos
                let shareURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("ClipCourt_Share_\(Int(Date().timeIntervalSince1970)).mp4")
                try? FileManager.default.copyItem(at: outputURL, to: shareURL)

                // Save to photo library
                try await exportService.saveToPhotoLibrary(url: outputURL)

                await MainActor.run {
                    self.exportedFileURL = shareURL
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

        // Poll progress from service (stored for cancellation, weak self to avoid leak)
        progressPollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled, await self.state == .exporting {
                let currentProgress = self.exportService.progress
                await MainActor.run { self.progress = currentProgress }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    /// Cancel an in-progress export.
    func cancelExport() {
        exportTask?.cancel()
        progressPollTask?.cancel()
        progressPollTask = nil
        exportService.cancelExport()
        state = .idle
        progress = 0
    }

    /// Reset state after viewing completion/error.
    func reset() {
        // Clean up the share copy and any accumulated temp files
        if let url = exportedFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        exportedFileURL = nil
        cleanupStaleShareCopies()
        state = .idle
        progress = 0
        settings = .default
    }

    // MARK: - Temp File Cleanup

    /// Remove all ClipCourt share copies from the temp directory.
    /// Prevents accumulation of orphaned share files from prior exports.
    private func cleanupStaleShareCopies() {
        let tempDir = FileManager.default.temporaryDirectory
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: nil
        ) else { return }

        for file in contents where file.lastPathComponent.hasPrefix("ClipCourt_Share_")
            && file.pathExtension == "mp4" {
            // Don't delete the currently-tracked share file
            if file != exportedFileURL {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}
