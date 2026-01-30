// PlayerView.swift
// ClipCourt
//
// The main editing screen: video playback + toggle + timeline + export access.
// Supports both portrait (VStack) and landscape (split panel) layouts.
// "This is where I eat lunch" — and this is where users eat their HIGHLIGHTS.

import AVKit
import SwiftUI

struct PlayerView: View {

    // MARK: - Environment

    @Environment(PlayerViewModel.self) private var viewModel
    @Environment(ExportViewModel.self) private var exportViewModel
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var showTimelineGuide = false

    // MARK: - Computed

    /// True when in landscape (compact vertical size class)
    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    // MARK: - Body

    var body: some View {
        @Bindable var exportVM = exportViewModel

        GeometryReader { outerProxy in
            if outerProxy.size.width > outerProxy.size.height {
                landscapeLayout(size: outerProxy.size)
            } else {
                portraitLayout
            }
        }
        .background(Color.ccBackground.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.35), value: isLandscape)
        .sheet(isPresented: $exportVM.showExportSheet) {
            ExportView()
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Portrait Layout (Design.md § Layout — Portrait)

    private var portraitLayout: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Video Player
                videoPlayerSection
                    .overlay(alignment: .center) { fastForwardOverlay }
                    .overlay { videoGlowBorder }

                // Status Row
                statusRow
                    .padding(.horizontal, 16)
                    .frame(height: 36)

                // Scrub Bar
                scrubBar
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                // Segment Timeline (Design.md: 48pt portrait)
                HStack(spacing: 6) {
                    SegmentTimelineView()
                        .frame(height: Constants.UI.timelineHeight)

                    timelineInfoButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Playback Controls Row
                playbackControlsRow
                    .frame(height: 52)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // Toggle Button (72pt portrait)
                toggleButton(height: 72)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                Spacer(minLength: 12)

                // Export Bar
                exportBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Landscape Layout (Design.md § Layout — Landscape)

    private func landscapeLayout(size: CGSize) -> some View {
        HStack(spacing: 0) {
            // Left 70%: Video player (full height)
            videoPlayerSection
                .overlay(alignment: .center) { fastForwardOverlay }
                .overlay { videoGlowBorder }
                .frame(width: size.width * 0.7)
                .frame(maxHeight: .infinity)
                .clipped()

            // Right 30%: All controls in scrollable column
            landscapeRightPanel
                .frame(width: size.width * 0.3)
                .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Landscape Right Panel (Design.md § Right Panel Layout)

    private var landscapeRightPanel: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                // Status indicator + timestamp
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.isIncluding ? "record.circle" : "circle")
                            .font(.caption)
                            .foregroundStyle(viewModel.isIncluding ? Color.ccInclude : Color.ccTextSecondary)
                            .symbolEffect(.pulse, isActive: viewModel.isIncluding)

                        Text(viewModel.isIncluding ? "RECORDING" : "PAUSED")
                            .font(.caption.bold())
                            .tracking(1.5)
                            .foregroundStyle(viewModel.isIncluding ? Color.ccInclude : Color.ccTextSecondary)
                    }

                    Text("\(TimeFormatter.format(viewModel.currentTime)) / \(TimeFormatter.format(viewModel.duration))")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Color.ccTextSecondary)
                }

                // Scrub bar
                scrubBar
                    .padding(.horizontal, 4)

                // Segment timeline (36pt in landscape)
                HStack(spacing: 4) {
                    SegmentTimelineView()
                        .frame(height: 36)

                    timelineInfoButton
                }
                .padding(.horizontal, 4)

                // Playback controls (compact row)
                HStack(spacing: 16) {
                    // Skip Back 15s
                    Button {
                        HapticManager.skip()
                        viewModel.seek(to: max(0, viewModel.currentTime - 15))
                    } label: {
                        Image(systemName: "gobackward.15")
                            .font(.body)
                            .foregroundStyle(Color.ccTextSecondary)
                            .frame(width: 40, height: 40)
                    }

                    // Play/Pause
                    Button {
                        HapticManager.playPause()
                        viewModel.togglePlayPause()
                    } label: {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundStyle(Color.ccTextPrimary)
                            .contentTransition(.symbolEffect(.replace.downUp))
                            .frame(width: 44, height: 44)
                    }

                    // Skip Forward 15s / Fast Forward
                    skipForwardButton(iconSize: .body, frameSize: 40)
                }

                // Speed selector
                landscapeSpeedSelector

                // Toggle button (48pt landscape — compact)
                toggleButton(height: 48)
                    .padding(.horizontal, 8)

                // Export bar
                landscapeExportButton
                    .padding(.horizontal, 8)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
        }
    }

    // MARK: - Shared Components

    // Video Player
    private var videoPlayerSection: some View {
        VideoPlayer(player: viewModel.playerService.player)
            .disabled(true)
    }

    // Fast Forward Overlay
    @ViewBuilder
    private var fastForwardOverlay: some View {
        if viewModel.isFastForwarding {
            HStack(spacing: 6) {
                Image(systemName: "forward.fill")
                Text("2×")
                    .font(.title3.bold())
            }
            .foregroundStyle(Color.ccSpeed)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .transition(.opacity.animation(.easeIn(duration: 0.15)))
        }
    }

    // Video border glow when including
    @ViewBuilder
    private var videoGlowBorder: some View {
        if viewModel.isIncluding {
            RoundedRectangle(cornerRadius: 0)
                .strokeBorder(Color.ccInclude.opacity(0.25), lineWidth: 3)
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.3), value: viewModel.isIncluding)
        }
    }

    // Status Row (portrait only)
    private var statusRow: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: viewModel.isIncluding ? "record.circle" : "circle")
                    .font(.caption)
                    .foregroundStyle(viewModel.isIncluding ? Color.ccInclude : Color.ccTextSecondary)
                    .symbolEffect(.pulse, isActive: viewModel.isIncluding)

                Text(viewModel.isIncluding ? "RECORDING" : "PAUSED")
                    .font(.caption.bold())
                    .tracking(1.5)
                    .foregroundStyle(viewModel.isIncluding ? Color.ccInclude : Color.ccTextSecondary)
            }

            Spacer()

            Text("\(TimeFormatter.format(viewModel.currentTime)) / \(TimeFormatter.format(viewModel.duration))")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(Color.ccTextSecondary)
        }
    }

    // Scrub Bar
    private var scrubBar: some View {
        Slider(
            value: Binding(
                get: { viewModel.currentTime },
                set: { viewModel.seek(to: $0) }
            ),
            in: 0...max(viewModel.duration, 0.01)
        )
        .tint(Color.ccTextPrimary.opacity(0.8))
        .frame(height: 44)
    }

    // Playback Controls Row (portrait)
    private var playbackControlsRow: some View {
        HStack(spacing: 0) {
            Button {
                HapticManager.skip()
                viewModel.seek(to: max(0, viewModel.currentTime - 15))
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.title3)
                    .foregroundStyle(Color.ccTextSecondary)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Button {
                HapticManager.playPause()
                viewModel.togglePlayPause()
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
                    .foregroundStyle(Color.ccTextPrimary)
                    .contentTransition(.symbolEffect(.replace.downUp))
                    .frame(width: 52, height: 52)
            }

            Spacer()

            skipForwardButton(iconSize: .title3, frameSize: 44)

            Spacer()

            speedSelector
        }
    }

    // Skip Forward button (shared, parameterized)
    private func skipForwardButton(iconSize: Font, frameSize: CGFloat) -> some View {
        Image(systemName: viewModel.isFastForwarding ? "forward.fill" : "goforward.15")
            .font(iconSize)
            .foregroundStyle(viewModel.isFastForwarding ? Color.ccSpeed : Color.ccTextSecondary)
            .frame(width: frameSize, height: frameSize)
            .contentShape(Rectangle())
            .onTapGesture {
                HapticManager.skip()
                viewModel.seek(to: min(viewModel.duration, viewModel.currentTime + 15))
            }
            .onLongPressGesture(minimumDuration: 0.3) {
            } onPressingChanged: { pressing in
                if pressing {
                    HapticManager.fastForwardEngage()
                    viewModel.beginFastForward()
                } else if viewModel.isFastForwarding {
                    HapticManager.fastForwardRelease()
                    viewModel.endFastForward()
                }
            }
    }

    // Speed Selector (portrait)
    private var speedSelector: some View {
        Menu {
            ForEach(PlaybackSpeed.allCases) { speed in
                Button(speed.displayName) {
                    HapticManager.speedChange()
                    viewModel.setPlaybackSpeed(speed)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "gauge.with.needle.fill")
                    .font(.caption2)
                Text(viewModel.playbackSpeed.displayName)
                    .font(.caption.bold())
            }
            .foregroundStyle(Color.ccTextSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.ccSurfaceElevated, in: Capsule())
        }
    }

    // Speed Selector (landscape — centered below controls)
    private var landscapeSpeedSelector: some View {
        Menu {
            ForEach(PlaybackSpeed.allCases) { speed in
                Button(speed.displayName) {
                    HapticManager.speedChange()
                    viewModel.setPlaybackSpeed(speed)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "gauge.with.needle.fill")
                    .font(.caption2)
                Text(viewModel.playbackSpeed.displayName)
                    .font(.caption.bold())
            }
            .foregroundStyle(Color.ccTextSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.ccSurfaceElevated, in: Capsule())
        }
    }

    // Toggle Button (shared, parameterized height)
    private func toggleButton(height: CGFloat) -> some View {
        Button {
            if viewModel.isIncluding {
                HapticManager.toggleOff()
            } else {
                HapticManager.toggleOn()
            }
            viewModel.toggleInclude()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: viewModel.isIncluding ? "record.circle" : "circle")
                    .font(.title3)
                    .symbolEffect(.pulse, isActive: viewModel.isIncluding)

                Text(viewModel.isIncluding ? "RECORDING" : "TAP TO RECORD")
                    .font(.headline)
                    .fontWeight(viewModel.isIncluding ? .bold : .medium)
            }
            .foregroundStyle(viewModel.isIncluding ? Color.ccInclude : Color.ccTextSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                viewModel.isIncluding
                    ? Color.ccInclude.opacity(0.15)
                    : Color.ccSurface
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        viewModel.isIncluding ? Color.ccInclude : Color.ccExclude,
                        lineWidth: viewModel.isIncluding ? 2.5 : 2
                    )
            )
            .shadow(
                color: viewModel.isIncluding ? Color.ccInclude.opacity(0.4) : .clear,
                radius: 8
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: viewModel.isIncluding)
    }

    // Export Bar (portrait)
    private var exportBar: some View {
        HStack {
            Button {
                viewModel.closeProject()
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.title3)
                    .foregroundStyle(Color.ccTextSecondary)
            }

            Spacer()

            if let project = viewModel.project {
                Text("\(TimeFormatter.format(project.includedDuration)) selected")
                    .font(.caption)
                    .foregroundStyle(Color.ccTextSecondary)
            }

            Spacer()

            exportPill
        }
    }

    // Export button (landscape right panel)
    private var landscapeExportButton: some View {
        HStack {
            Button {
                viewModel.closeProject()
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.caption)
                    .foregroundStyle(Color.ccTextSecondary)
            }

            Spacer()

            if let project = viewModel.project {
                Text("\(TimeFormatter.format(project.includedDuration)) selected")
                    .font(.caption)
                    .foregroundStyle(Color.ccTextSecondary)
            }

            Spacer()

            exportPill
        }
    }

    // Export pill button (shared)
    private var exportPill: some View {
        Button {
            HapticManager.exportTap()
            exportViewModel.showExportSheet = true
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.ccTextPrimary)
                .padding(.horizontal, 20)
                .frame(height: 44)
                .background(Color.ccExport, in: Capsule())
        }
        .disabled(viewModel.segments.filter(\.isIncluded).isEmpty)
        .opacity(viewModel.segments.filter(\.isIncluded).isEmpty ? 0.4 : 1.0)
    }

    // MARK: - Timeline Info Guide

    private var timelineInfoButton: some View {
        Button {
            showTimelineGuide = true
        } label: {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(Color.ccTextTertiary)
        }
        .alert("Timeline Tips", isPresented: $showTimelineGuide) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("• Tap the timeline to seek\n• Long-press a clip to delete or restore it\n• Pinch to zoom in on the timeline\n• Drag to scroll when zoomed")
        }
    }
}

// MARK: - Preview

#Preview("Portrait") {
    PlayerView()
        .environment(PlayerViewModel())
        .environment(ExportViewModel())
}

#Preview("Landscape") {
    PlayerView()
        .environment(PlayerViewModel())
        .environment(ExportViewModel())
        .previewInterfaceOrientation(.landscapeLeft)
}
