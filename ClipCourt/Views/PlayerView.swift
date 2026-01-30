// PlayerView.swift
// ClipCourt
//
// The main editing screen: video playback + toggle + timeline + export access.
// "This is where I eat lunch" — and this is where users eat their HIGHLIGHTS.

import AVKit
import SwiftUI

struct PlayerView: View {

    // MARK: - Environment

    @Environment(PlayerViewModel.self) private var viewModel
    @Environment(ExportViewModel.self) private var exportViewModel

    // MARK: - Body

    var body: some View {
        @Bindable var exportVM = exportViewModel

        GeometryReader { geometry in
            VStack(spacing: 0) {

                // MARK: - Video Player
                videoPlayerSection
                    .overlay(alignment: .center) {
                        fastForwardOverlay
                    }
                    .overlay {
                        // Video player border glow when including (Design.md)
                        if viewModel.isIncluding {
                            RoundedRectangle(cornerRadius: 0)
                                .strokeBorder(Color.ccInclude.opacity(0.25), lineWidth: 3)
                                .allowsHitTesting(false)
                                .animation(.easeInOut(duration: 0.3), value: viewModel.isIncluding)
                        }
                    }

                // MARK: - Status Row
                statusRow
                    .padding(.horizontal, 16)
                    .frame(height: 36)

                // MARK: - Scrub Bar
                scrubBar
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                // MARK: - Segment Timeline
                SegmentTimelineView()
                    .frame(height: 48)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // MARK: - Playback Controls Row
                playbackControlsRow
                    .frame(height: 52)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // MARK: - The Big Toggle Button
                toggleButton
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                Spacer(minLength: 12)

                // MARK: - Export Bar
                exportBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .background(Color.ccBackground)
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

    // MARK: - Video Player Section

    private var videoPlayerSection: some View {
        VideoPlayer(player: viewModel.playerService.player)
            .disabled(true)  // Disable default controls; we provide our own
    }

    // MARK: - Fast Forward Overlay

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

    // MARK: - Status Row (toggle state + timestamp)

    private var statusRow: some View {
        HStack {
            // Toggle state indicator
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

            // Timestamp
            Text("\(TimeFormatter.format(viewModel.currentTime)) / \(TimeFormatter.format(viewModel.duration))")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(Color.ccTextSecondary)
        }
    }

    // MARK: - Scrub Bar

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

    // MARK: - Playback Controls Row

    private var playbackControlsRow: some View {
        HStack(spacing: 0) {
            // Skip Back 15s
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

            // Play/Pause
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

            // Skip Forward 15s (tap) / Fast Forward (hold)
            Button {
                HapticManager.skip()
                viewModel.seek(to: min(viewModel.duration, viewModel.currentTime + 15))
            } label: {
                Image(systemName: viewModel.isFastForwarding ? "forward.fill" : "goforward.15")
                    .font(.title3)
                    .foregroundStyle(viewModel.isFastForwarding ? Color.ccSpeed : Color.ccTextSecondary)
                    .frame(width: 44, height: 44)
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.3)
                    .onEnded { _ in
                        HapticManager.fastForwardEngage()
                        viewModel.beginFastForward()
                    }
            )

            Spacer()

            // Speed Selector
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
    }

    // MARK: - The Big Toggle Button (Design.md: 72pt tall, full width)

    private var toggleButton: some View {
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
            .frame(height: 72)
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

    // MARK: - Export Bar

    private var exportBar: some View {
        HStack {
            // Close project
            Button {
                viewModel.closeProject()
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.title3)
                    .foregroundStyle(Color.ccTextSecondary)
            }

            Spacer()

            // Included duration summary
            if let project = viewModel.project {
                Text("\(TimeFormatter.format(project.includedDuration)) selected")
                    .font(.caption)
                    .foregroundStyle(Color.ccTextSecondary)
            }

            Spacer()

            // Export button (Signal Blue, pill shape)
            Button {
                HapticManager.exportTap()
                exportViewModel.showExportSheet = true
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .frame(height: 44)
                    .background(Color.ccExport, in: Capsule())
            }
            .disabled(viewModel.segments.filter(\.isIncluded).isEmpty)
            .opacity(viewModel.segments.filter(\.isIncluded).isEmpty ? 0.4 : 1.0)
        }
    }
}

// MARK: - Preview

#Preview {
    PlayerView()
        .environment(PlayerViewModel())
        .environment(ExportViewModel())
}
