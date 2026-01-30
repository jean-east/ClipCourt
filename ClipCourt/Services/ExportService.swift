// ExportService.swift
// ClipCourt
//
// Two export pipelines: lossless (passthrough) and lossy (re-encoded).
// "My knob tastes funny" — but my exports taste like PRISTINE H.264.

import AVFoundation
import Photos

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
    case writerFailed(String)
    case cancelled
    case photoLibrarySaveFailed(String)

    var errorDescription: String? {
        switch self {
        case .noIncludedSegments:
            "No segments are marked for inclusion."
        case .compositionFailed(let reason):
            "Failed to build composition: \(reason)"
        case .exportSessionFailed(let reason):
            "Export failed: \(reason)"
        case .writerFailed(let reason):
            "Re-encoding failed: \(reason)"
        case .cancelled:
            "Export was cancelled."
        case .photoLibrarySaveFailed(let reason):
            "Failed to save to Photos: \(reason)"
        }
    }
}

// MARK: - Implementation

final class ExportService: VideoExporting {

    // MARK: - State

    private(set) var progress: Double = 0
    private var exportSession: AVAssetExportSession?
    private var assetWriter: AVAssetWriter?
    private var isCancelled = false

    // MARK: - Composition Builder (Shared)

    /// Builds an AVMutableComposition from the included segments.
    private func buildComposition(
        from asset: AVAsset,
        segments: [Segment]
    ) async throws -> AVMutableComposition {

        let includedSegments = segments
            .filter(\.isIncluded)
            .sorted()

        guard !includedSegments.isEmpty else {
            throw ExportError.noIncludedSegments
        }

        let composition = AVMutableComposition()

        // Load source tracks
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)

        guard let sourceVideoTrack = videoTracks.first else {
            throw ExportError.compositionFailed("No video track in source asset")
        }

        let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        let compositionAudioTrack: AVMutableCompositionTrack?
        if let sourceAudioTrack = audioTracks.first {
            compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )

            var insertionTime = CMTime.zero
            for segment in includedSegments {
                let startTime = CMTime(seconds: segment.startTime, preferredTimescale: 600)
                let endTime = CMTime(seconds: segment.endTime, preferredTimescale: 600)
                let timeRange = CMTimeRange(start: startTime, end: endTime)

                try compositionVideoTrack?.insertTimeRange(
                    timeRange,
                    of: sourceVideoTrack,
                    at: insertionTime
                )
                try compositionAudioTrack?.insertTimeRange(
                    timeRange,
                    of: sourceAudioTrack,
                    at: insertionTime
                )

                insertionTime = CMTimeAdd(insertionTime, CMTimeSubtract(endTime, startTime))
            }
        } else {
            compositionAudioTrack = nil

            var insertionTime = CMTime.zero
            for segment in includedSegments {
                let startTime = CMTime(seconds: segment.startTime, preferredTimescale: 600)
                let endTime = CMTime(seconds: segment.endTime, preferredTimescale: 600)
                let timeRange = CMTimeRange(start: startTime, end: endTime)

                try compositionVideoTrack?.insertTimeRange(
                    timeRange,
                    of: sourceVideoTrack,
                    at: insertionTime
                )

                insertionTime = CMTimeAdd(insertionTime, CMTimeSubtract(endTime, startTime))
            }
        }

        // Preserve the source video's preferred transform (orientation)
        let preferredTransform = try await sourceVideoTrack.load(.preferredTransform)
        compositionVideoTrack?.preferredTransform = preferredTransform

        return composition
    }

    // MARK: - Output URL Helper

    private func makeOutputURL() -> URL {
        let filename = "ClipCourt_\(Int(Date().timeIntervalSince1970)).mp4"
        return FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }

    // MARK: - Path A: Lossless Export

    func exportLossless(asset: AVAsset, segments: [Segment]) async throws -> URL {
        isCancelled = false
        progress = 0

        let composition = try await buildComposition(from: asset, segments: segments)
        let outputURL = makeOutputURL()

        // Clean up any existing file at the output path
        try? FileManager.default.removeItem(at: outputURL)

        guard let session = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw ExportError.exportSessionFailed("Could not create export session")
        }

        session.outputURL = outputURL
        session.outputFileType = .mp4
        self.exportSession = session

        // Monitor progress on a timer
        let progressTask = Task {
            while !Task.isCancelled {
                await MainActor.run {
                    self.progress = Double(session.progress)
                }
                try await Task.sleep(for: .milliseconds(100))
            }
        }

        // Run the export
        await session.export()
        progressTask.cancel()

        if isCancelled {
            try? FileManager.default.removeItem(at: outputURL)
            throw ExportError.cancelled
        }

        switch session.status {
        case .completed:
            await MainActor.run { self.progress = 1.0 }
            return outputURL
        case .failed:
            let reason = session.error?.localizedDescription ?? "Unknown error"
            throw ExportError.exportSessionFailed(reason)
        case .cancelled:
            throw ExportError.cancelled
        default:
            throw ExportError.exportSessionFailed("Unexpected status: \(session.status.rawValue)")
        }
    }

    // MARK: - Path B: Lossy Re-encoded Export

    func exportLossy(
        asset: AVAsset,
        segments: [Segment],
        settings: ExportSettings
    ) async throws -> URL {
        isCancelled = false
        progress = 0

        let composition = try await buildComposition(from: asset, segments: segments)
        let outputURL = makeOutputURL()

        try? FileManager.default.removeItem(at: outputURL)

        // Reader
        let reader = try AVAssetReader(asset: composition)

        let videoTracks = try await composition.loadTracks(withMediaType: .video)
        let audioTracks = try await composition.loadTracks(withMediaType: .audio)

        // Video output — decompress to raw pixel buffers
        let videoOutput = AVAssetReaderTrackOutput(
            track: videoTracks[0],
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
        )
        videoOutput.alwaysCopiesSampleData = false
        reader.add(videoOutput)

        // Audio output (if present)
        var audioOutput: AVAssetReaderTrackOutput?
        if let audioTrack = audioTracks.first {
            let output = AVAssetReaderTrackOutput(
                track: audioTrack,
                outputSettings: [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsFloatKey: false
                ]
            )
            output.alwaysCopiesSampleData = false
            reader.add(output)
            audioOutput = output
        }

        // Writer
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        self.assetWriter = writer

        // Video input — H.264 encoding
        let naturalSize = try await videoTracks[0].load(.naturalSize)
        let transform = try await videoTracks[0].load(.preferredTransform)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: naturalSize.width,
            AVVideoHeightKey: naturalSize.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 10_000_000 * settings.outputQuality,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.transform = transform
        videoInput.expectsMediaDataInRealTime = false
        writer.add(videoInput)

        // Audio input — AAC encoding
        var audioInput: AVAssetWriterInput?
        if audioOutput != nil {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 2,
                AVSampleRateKey: 44100,
                AVEncoderBitRateKey: 128_000
            ]
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            input.expectsMediaDataInRealTime = false
            writer.add(input)
            audioInput = input
        }

        // Start reading and writing
        guard reader.startReading() else {
            throw ExportError.writerFailed(reader.error?.localizedDescription ?? "Reader failed to start")
        }
        guard writer.startWriting() else {
            throw ExportError.writerFailed(writer.error?.localizedDescription ?? "Writer failed to start")
        }
        writer.startSession(atSourceTime: .zero)

        // Estimated total for progress tracking
        let duration = try await composition.load(.duration)
        let totalSeconds = CMTimeGetSeconds(duration)

        // Process video samples
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                while let sampleBuffer = videoOutput.copyNextSampleBuffer() {
                    if self?.isCancelled == true { break }
                    while !videoInput.isReadyForMoreMediaData {
                        try? await Task.sleep(for: .milliseconds(10))
                    }
                    videoInput.append(sampleBuffer)

                    let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    let currentSeconds = CMTimeGetSeconds(timestamp)
                    await MainActor.run {
                        self?.progress = min(currentSeconds / totalSeconds, 1.0)
                    }
                }
                videoInput.markAsFinished()
            }

            if let audioOutput, let audioInput {
                group.addTask { [weak self] in
                    while let sampleBuffer = audioOutput.copyNextSampleBuffer() {
                        if self?.isCancelled == true { break }
                        while !audioInput.isReadyForMoreMediaData {
                            try? await Task.sleep(for: .milliseconds(10))
                        }
                        audioInput.append(sampleBuffer)
                    }
                    audioInput.markAsFinished()
                }
            }
        }

        if isCancelled {
            reader.cancelReading()
            await writer.cancelWriting()
            try? FileManager.default.removeItem(at: outputURL)
            throw ExportError.cancelled
        }

        await writer.finishWriting()

        if writer.status == .failed {
            throw ExportError.writerFailed(writer.error?.localizedDescription ?? "Unknown writer error")
        }

        await MainActor.run { self.progress = 1.0 }
        return outputURL
    }

    // MARK: - Save to Photos

    func saveToPhotoLibrary(url: URL) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(
                with: .video,
                fileURL: url,
                options: nil
            )
        }

        // Clean up temp file
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Cancellation

    func cancelExport() {
        isCancelled = true
        exportSession?.cancelExport()
        assetWriter?.cancelWriting()
    }
}
