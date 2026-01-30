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
        @Bindable var vm = viewModel

        GeometryReader { geometry in
            VStack(spacing: 0) {

                // MARK: - Video Player
                videoPlayerSection
                    .frame(height: geometry.size.height * 0.55)

                // MARK: - Controls Overlay
                controlsSection

                // MARK: - Segment Timeline
                SegmentTimelineView()
                    .frame(height: 60)
                    .padding(.horizontal)

                // MARK: - Bottom Bar
                bottomBar
            }
        }
        .background(Color.black)
        .overlay {
            // Include/Exclude visual border indicator
            if viewModel.isIncluding {
                RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(Color.red, lineWidth: 4)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .sheet(isPresented: $exportViewModel.showExportSheet) {
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
            .gesture(
                LongPressGesture(minimumDuration: 0.3)
                    .onChanged { _ in
                        viewModel.beginFastForward()
                    }
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onEnded { _ in
                        viewModel.endFastForward()
                    }
            )
            .overlay(alignment: .topTrailing) {
                if viewModel.isFastForwarding {
                    Label("2× Fast Forward", systemImage: "forward.fill")
                        .font(.caption.bold())
                        .padding(8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(12)
                        .transition(.opacity)
                }
            }
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        VStack(spacing: 12) {
            // Time display
            HStack {
                Text(TimeFormatter.format(viewModel.currentTime))
                    .monospacedDigit()
                Spacer()
                Text(TimeFormatter.format(viewModel.duration))
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal)

            // Scrub slider
            Slider(
                value: Binding(
                    get: { viewModel.currentTime },
                    set: { viewModel.seek(to: $0) }
                ),
                in: 0...max(viewModel.duration, 0.01)
            )
            .tint(viewModel.isIncluding ? .red : .white)
            .padding(.horizontal)

            // Playback controls row
            HStack(spacing: 24) {
                // Speed picker
                Menu {
                    ForEach(PlaybackSpeed.allCases) { speed in
                        Button(speed.displayName) {
                            viewModel.setPlaybackSpeed(speed)
                        }
                    }
                } label: {
                    Text(viewModel.playbackSpeed.displayName)
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                Spacer()

                // Play/Pause
                Button {
                    viewModel.togglePlayPause()
                } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                }

                Spacer()

                // Include/Exclude toggle
                Button {
                    viewModel.toggleInclude()
                } label: {
                    Image(systemName: viewModel.isIncluding ? "record.circle.fill" : "record.circle")
                        .font(.title)
                        .foregroundStyle(viewModel.isIncluding ? .red : .white)
                        .symbolEffect(.pulse, isActive: viewModel.isIncluding)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            // Close project
            Button {
                viewModel.closeProject()
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.title3)
            }

            Spacer()

            // Included duration summary
            if let project = viewModel.project {
                Text("\(TimeFormatter.format(project.includedDuration)) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Export button
            Button {
                exportViewModel.showExportSheet = true
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.segments.filter(\.isIncluded).isEmpty)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

// MARK: - Preview

#Preview {
    PlayerView()
        .environment(PlayerViewModel())
        .environment(ExportViewModel())
}
