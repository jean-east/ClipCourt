// ExportService.swift
// ClipCourt
//
// Two export pipelines: lossless (passthrough) and lossy (re-encoded).
// "My knob tastes funny" — but my exports taste like PRISTINE H.264
// wrapped in beautiful MPEG-4 containers with AAC audio frosting.
//
// Path A (Lossless): AVAssetExportSession with passthrough preset.
//   → Fast, no quality loss, cuts snap to nearest keyframe boundary.
// Path B (Lossy): AVAssetReader + AVAssetWriter with H.264/AAC encoding.
//   → Frame-accurate cuts, configurable quality, smaller output.

import AVFoundation
import Photos

// MARK: - Protocol

/// Protocol for video export — enables testing and swapping implementations.
protocol VideoExporting {
    var progress: Double { get }
    func exportLossless(asset: AVAsset, segments: [Segment]) async throws -> URL
    func exportLossy(asset: AVAsset, segments: [Segment], settings: ExportSettings) async throws -> URL
    func saveToPhotoLibrary(url: URL) async throws
    func cancelExport()
}

// MARK: - Errors

enum ExportError: LocalizedError {
    case noIncludedSegments
    case compositionFailed(String)
    case exportSessionFailed(String)
    case exportSessionCreationFailed
    case readerCreationFailed(String)
    case writerCreationFailed(String)
    case readerStartFailed(String)
    case writerStartFailed(String)
    case writerFailed(String)
    case readerFailed(String)
    case cancelled
    case photoLibrarySaveFailed(String)
    case noVideoTrackInSource

    var errorDescription: String? {
        switch self {
        case .noIncludedSegments:
            "No segments are marked for inclusion."
        case .compositionFailed(let reason):
            "Failed to build composition: \(reason)"
        case .exportSessionFailed(let reason):
            "Export failed: \(reason)"
        case .exportSessionCreationFailed:
            "Could not create export session. The passthrough preset may not be compatible with this video."
        case .readerCreationFailed(let reason):
            "Could not create asset reader: \(reason)"
        case .writerCreationFailed(let reason):
            "Could not create asset writer: \(reason)"
        case .readerStartFailed(let reason):
            "Reader failed to start: \(reason)"
        case .writerStartFailed(let reason):
            "Writer failed to start: \(reason)"
        case .writerFailed(let reason):
            "Re-encoding failed: \(reason)"
        case .readerFailed(let reason):
            "Reading failed: \(reason)"
        case .cancelled:
            "Export was cancelled."
        case .photoLibrarySaveFailed(let reason):
            "Failed to save to Photos: \(reason)"
        case .noVideoTrackInSource:
            "No video track found in the source asset."
        }
    }
}

// MARK: - Implementation

final class ExportService: VideoExporting {

    // MARK: - Thread-Safe State

    /// Lock protecting mutable state accessed from multiple threads.
    private let lock = NSLock()

    private var _progress: Double = 0
    private var _isCancelled = false

    /// Current export progress (0.0–1.0). Thread-safe.
    var progress: Double {
        lock.lock()
        defer { lock.unlock() }
        return _progress
    }

    private func setProgress(_ value: Double) {
        lock.lock()
        _progress = min(max(value, 0), 1.0)
        lock.unlock()
    }

    private var isCancelled: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _isCancelled
        }
        set {
            lock.lock()
            _isCancelled = newValue
            lock.unlock()
        }
    }

    // MARK: - Active Export References (for cancellation)

    private var exportSession: AVAssetExportSession?
    private var activeWriter: AVAssetWriter?
    private var activeReader: AVAssetReader?

    // MARK: - Composition Builder (Shared by Both Paths)

    /// Builds an AVMutableComposition from the included segments of the source asset.
    ///
    /// The composition contains only the "kept" time ranges, concatenated in order.
    /// Both video and audio tracks (if present) are included.
    /// The source video's orientation (preferredTransform) is preserved.
    ///
    /// - Parameters:
    ///   - asset: The source AVAsset from Photos.
    ///   - segments: All segments; only those with `isIncluded == true` are used.
    /// - Returns: An AVMutableComposition ready for export.
    /// - Throws: `ExportError` if the source has no video track or composition fails.
    private func buildComposition(
        from asset: AVAsset,
        segments: [Segment]
    ) async throws -> AVMutableComposition {
        let includedSegments = segments
            .filter { $0.isIncluded && $0.isValid }
            .sorted()

        guard !includedSegments.isEmpty else {
            throw ExportError.noIncludedSegments
        }

        let composition = AVMutableComposition()

        // Load source tracks
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)

        guard let sourceVideoTrack = videoTracks.first else {
            throw ExportError.noVideoTrackInSource
        }

        // Create composition tracks
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw ExportError.compositionFailed("Could not add video track to composition")
        }

        // Audio track is optional — some videos have no audio
        let sourceAudioTrack = audioTracks.first
        let compositionAudioTrack: AVMutableCompositionTrack? = sourceAudioTrack.flatMap {_ in
            composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        }

        // Insert each included segment into the composition
        var insertionTime = CMTime.zero

        for segment in includedSegments {
            let startTime = CMTime(seconds: segment.startTime, preferredTimescale: 600)
            let endTime = CMTime(seconds: segment.endTime, preferredTimescale: 600)
            let timeRange = CMTimeRange(start: startTime, end: endTime)

            // Insert video
            try compositionVideoTrack.insertTimeRange(
                timeRange,
                of: sourceVideoTrack,
                at: insertionTime
            )

            // Insert audio (if available)
            if let sourceAudioTrack, let compositionAudioTrack {
                try compositionAudioTrack.insertTimeRange(
                    timeRange,
                    of: sourceAudioTrack,
                    at: insertionTime
                )
            }

            let segmentDuration = CMTimeSubtract(endTime, startTime)
            insertionTime = CMTimeAdd(insertionTime, segmentDuration)
        }

        // Preserve the source video's orientation (portrait/landscape rotation)
        let preferredTransform = try await sourceVideoTrack.load(.preferredTransform)
        compositionVideoTrack.preferredTransform = preferredTransform

        return composition
    }

    // MARK: - Output URL Helper

    /// Creates a unique temporary file URL for export output.
    private func makeOutputURL() -> URL {
        let timestamp = Int(Date().timeIntervalSince1970)
        let random = Int.random(in: 1000...9999)
        let filename = "ClipCourt_\(timestamp)_\(random).mp4"
        return FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }

    /// Cleans up a temporary file. Silently ignores errors.
    private func cleanupTempFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Path A: Lossless Export (AVAssetExportSession)

    /// Export using passthrough preset — no re-encoding.
    ///
    /// Builds a composition from included segments and exports via
    /// `AVAssetExportSession` with `AVAssetExportPresetPassthrough`.
    ///
    /// **Trade-offs:**
    /// - Fast (remux only, no transcoding)
    /// - No quality loss
    /// - Cuts land on nearest keyframe boundary (typically ±0.5s for sports video)
    ///
    /// - Parameters:
    ///   - asset: Source AVAsset from Photos.
    ///   - segments: All segments (only included ones are exported).
    /// - Returns: URL of the exported file in the temp directory.
    /// - Throws: `ExportError` on failure or cancellation.
    func exportLossless(asset: AVAsset, segments: [Segment]) async throws -> URL {
        // Reset state
        isCancelled = false
        setProgress(0)

        let composition = try await buildComposition(from: asset, segments: segments)
        let outputURL = makeOutputURL()

        // Remove any existing file at the output path
        cleanupTempFile(at: outputURL)

        // Create export session
        guard let session = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw ExportError.exportSessionCreationFailed
        }

        session.outputURL = outputURL
        session.outputFileType = .mp4
        self.exportSession = session

        // Cleanup on any exit path
        defer {
            self.exportSession = nil
        }

        // Monitor progress in background
        let progressTask = Task.detached { [weak self] in
            while !Task.isCancelled {
                let currentProgress = Double(session.progress)
                self?.setProgress(currentProgress)
                try await Task.sleep(for: .milliseconds(100))
            }
        }

        // Run the export
        await session.export()
        progressTask.cancel()

        // Check cancellation
        if isCancelled {
            cleanupTempFile(at: outputURL)
            throw ExportError.cancelled
        }

        // Handle result
        switch session.status {
        case .completed:
            setProgress(1.0)
            return outputURL

        case .failed:
            cleanupTempFile(at: outputURL)
            let reason = session.error?.localizedDescription ?? "Unknown error"
            throw ExportError.exportSessionFailed(reason)

        case .cancelled:
            cleanupTempFile(at: outputURL)
            throw ExportError.cancelled

        default:
            cleanupTempFile(at: outputURL)
            throw ExportError.exportSessionFailed("Unexpected export status: \(session.status.rawValue)")
        }
    }

    // MARK: - Path B: Lossy Re-encoded Export (AVAssetReader + AVAssetWriter)

    /// Export with re-encoding — frame-accurate cuts, configurable quality.
    ///
    /// Uses `AVAssetReader` to decode frames and `AVAssetWriter` to encode with
    /// H.264 video and AAC audio. Processes the composition built from included segments.
    ///
    /// **Trade-offs:**
    /// - Slower (full decode + encode cycle)
    /// - Frame-accurate cuts (not keyframe-limited)
    /// - Configurable output quality/size
    /// - Handles portrait/landscape via transform metadata
    ///
    /// - Parameters:
    ///   - asset: Source AVAsset from Photos.
    ///   - segments: All segments (only included ones are exported).
    ///   - settings: Export configuration (quality, etc.).
    /// - Returns: URL of the exported file in the temp directory.
    /// - Throws: `ExportError` on failure or cancellation.
    func exportLossy(
        asset: AVAsset,
        segments: [Segment],
        settings: ExportSettings
    ) async throws -> URL {
        // Reset state
        isCancelled = false
        setProgress(0)

        let composition = try await buildComposition(from: asset, segments: segments)
        let outputURL = makeOutputURL()

        // Remove any existing file
        cleanupTempFile(at: outputURL)

        // Cleanup on any exit path
        defer {
            self.activeReader = nil
            self.activeWriter = nil
        }

        // --- Set up Reader ---

        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: composition)
        } catch {
            throw ExportError.readerCreationFailed(error.localizedDescription)
        }
        self.activeReader = reader

        let videoTracks = try await composition.loadTracks(withMediaType: .video)
        let audioTracks = try await composition.loadTracks(withMediaType: .audio)

        guard let compositionVideoTrack = videoTracks.first else {
            throw ExportError.noVideoTrackInSource
        }

        // Video reader output — decompress to raw pixel buffers
        let videoOutput = AVAssetReaderTrackOutput(
            track: compositionVideoTrack,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
        )
        videoOutput.alwaysCopiesSampleData = false
        reader.add(videoOutput)

        // Audio reader output (if audio exists) — decompress to linear PCM
        var audioOutput: AVAssetReaderTrackOutput?
        if let audioTrack = audioTracks.first {
            let output = AVAssetReaderTrackOutput(
                track: audioTrack,
                outputSettings: [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsNonInterleaved: false
                ]
            )
            output.alwaysCopiesSampleData = false
            reader.add(output)
            audioOutput = output
        }

        // --- Set up Writer ---

        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        } catch {
            throw ExportError.writerCreationFailed(error.localizedDescription)
        }
        self.activeWriter = writer

        // Video writer input — H.264 encoding
        let naturalSize = try await compositionVideoTrack.load(.naturalSize)
        let transform = try await compositionVideoTrack.load(.preferredTransform)

        // Ensure even dimensions (H.264 requirement)
        let videoWidth = max(2, Int(naturalSize.width) & ~1)
        let videoHeight = max(2, Int(naturalSize.height) & ~1)

        // Scale bitrate by quality setting. 10 Mbps base is good for 1080p.
        let qualityMultiplier = max(0.1, settings.outputQuality)
        let videoBitRate = Int(10_000_000.0 * qualityMultiplier)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoWidth,
            AVVideoHeightKey: videoHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: videoBitRate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoExpectedSourceFrameRateKey: 30
            ]
        ]

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.transform = transform
        videoInput.expectsMediaDataInRealTime = false
        writer.add(videoInput)

        // Audio writer input — AAC encoding (if source has audio)
        var audioInput: AVAssetWriterInput?
        if audioOutput != nil {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 2,
                AVSampleRateKey: 44_100.0,
                AVEncoderBitRateKey: 128_000
            ]
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            input.expectsMediaDataInRealTime = false
            writer.add(input)
            audioInput = input
        }

        // --- Start Reading & Writing ---

        guard reader.startReading() else {
            cleanupTempFile(at: outputURL)
            let reason = reader.error?.localizedDescription ?? "Unknown reader error"
            throw ExportError.readerStartFailed(reason)
        }

        guard writer.startWriting() else {
            reader.cancelReading()
            cleanupTempFile(at: outputURL)
            let reason = writer.error?.localizedDescription ?? "Unknown writer error"
            throw ExportError.writerStartFailed(reason)
        }

        writer.startSession(atSourceTime: .zero)

        // Total duration for progress calculation
        let duration = try await composition.load(.duration)
        let totalSeconds = max(CMTimeGetSeconds(duration), 0.001) // Avoid division by zero

        // --- Sample Buffer Processing ---
        // Process video and audio concurrently using a task group.
        // Each runs on its own async task, appending sample buffers to the writer.

        await withTaskGroup(of: Void.self) { group in

            // Video processing task
            group.addTask { [weak self] in
                guard let self else { return }

                while !self.isCancelled && !Task.isCancelled {
                    guard let sampleBuffer = videoOutput.copyNextSampleBuffer() else {
                        break // No more video samples
                    }

                    // Wait until the writer input is ready
                    while !videoInput.isReadyForMoreMediaData {
                        if self.isCancelled || Task.isCancelled { break }
                        try? await Task.sleep(for: .milliseconds(5))
                    }

                    guard !self.isCancelled, !Task.isCancelled else { break }

                    videoInput.append(sampleBuffer)

                    // Update progress based on video timestamp
                    let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    let currentSeconds = CMTimeGetSeconds(timestamp)
                    if currentSeconds.isFinite {
                        self.setProgress(min(currentSeconds / totalSeconds, 0.99))
                    }
                }
                videoInput.markAsFinished()
            }

            // Audio processing task (if audio exists)
            if let audioOutput, let audioInput {
                group.addTask { [weak self] in
                    guard let self else { return }

                    while !self.isCancelled && !Task.isCancelled {
                        guard let sampleBuffer = audioOutput.copyNextSampleBuffer() else {
                            break // No more audio samples
                        }

                        while !audioInput.isReadyForMoreMediaData {
                            if self.isCancelled || Task.isCancelled { break }
                            try? await Task.sleep(for: .milliseconds(5))
                        }

                        guard !self.isCancelled, !Task.isCancelled else { break }

                        audioInput.append(sampleBuffer)
                    }
                    audioInput.markAsFinished()
                }
            }

            // Wait for both to complete
        }

        // --- Handle Results ---

        if isCancelled || Task.isCancelled {
            reader.cancelReading()
            writer.cancelWriting()
            cleanupTempFile(at: outputURL)
            throw ExportError.cancelled
        }

        // Check reader status
        if reader.status == .failed {
            writer.cancelWriting()
            cleanupTempFile(at: outputURL)
            let reason = reader.error?.localizedDescription ?? "Unknown reader error"
            throw ExportError.readerFailed(reason)
        }

        // Finish writing
        await writer.finishWriting()

        if writer.status == .failed {
            cleanupTempFile(at: outputURL)
            let reason = writer.error?.localizedDescription ?? "Unknown writer error"
            throw ExportError.writerFailed(reason)
        }

        setProgress(1.0)
        return outputURL
    }

    // MARK: - Save to Photo Library

    /// Saves the exported video to the user's Photo Library and cleans up the temp file.
    ///
    /// - Parameter url: URL of the exported video file.
    /// - Throws: `ExportError.photoLibrarySaveFailed` if the save fails.
    func saveToPhotoLibrary(url: URL) async throws {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = true // Move instead of copy — faster, cleans up temp
                request.addResource(with: .video, fileURL: url, options: options)
            }
        } catch {
            // Still try to clean up the temp file on failure
            cleanupTempFile(at: url)
            throw ExportError.photoLibrarySaveFailed(error.localizedDescription)
        }

        // The file was moved by Photos (shouldMoveFile = true), so no manual cleanup needed.
        // But if it somehow still exists, clean it up:
        cleanupTempFile(at: url)
    }

    // MARK: - Cancellation

    /// Cancel any in-progress export. Safe to call from any thread.
    func cancelExport() {
        isCancelled = true
        exportSession?.cancelExport()
        activeWriter?.cancelWriting()
        activeReader?.cancelReading()
    }
}
