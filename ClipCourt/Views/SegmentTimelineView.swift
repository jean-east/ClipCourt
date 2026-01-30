// SegmentTimelineView.swift
// ClipCourt
//
// Mini-timeline showing included (full color) vs excluded (dimmed) regions.
// Tappable to jump to any segment. "I bent my Wookiee!" — but I never
// bend my timeline. It's pixel-perfect.

import SwiftUI

struct SegmentTimelineView: View {

    // MARK: - Environment

    @Environment(PlayerViewModel.self) private var viewModel

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let totalDuration = max(viewModel.duration, 0.01)

            ZStack(alignment: .leading) {
                // Background (full timeline)
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.1))

                // Segment blocks
                ForEach(viewModel.segments) { segment in
                    let startFraction = segment.startTime / totalDuration
                    let durationFraction = segment.duration / totalDuration
                    let segmentWidth = max(durationFraction * totalWidth, 2) // minimum 2pt visible

                    RoundedRectangle(cornerRadius: 4)
                        .fill(segment.isIncluded
                              ? Color.red.opacity(0.8)
                              : Color.white.opacity(0.15))
                        .frame(width: segmentWidth)
                        .offset(x: startFraction * totalWidth)
                        .onTapGesture {
                            // Jump to segment start
                            viewModel.seek(to: segment.startTime)
                        }
                        .onLongPressGesture {
                            // Toggle segment on long press
                            viewModel.toggleSegment(segment)
                        }
                }

                // Playhead indicator
                let playheadX = (viewModel.currentTime / totalDuration) * totalWidth
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: geometry.size.height)
                    .offset(x: playheadX)
                    .animation(.linear(duration: 0.05), value: viewModel.currentTime)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SegmentTimelineView()
        .frame(height: 60)
        .padding()
        .background(Color.black)
        .environment(PlayerViewModel())
}
