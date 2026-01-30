// SegmentTimelineView.swift
// ClipCourt
//
// Mini-timeline showing included (Rally Green) vs excluded (dimmed) regions.
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
                // Background bar (Design.md: ccSurface, 8pt corner radius)
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.ccSurface)

                // Segment blocks
                ForEach(viewModel.segments) { segment in
                    let startFraction = segment.startTime / totalDuration
                    let durationFraction = segment.duration / totalDuration
                    let segmentWidth = max(durationFraction * totalWidth, 2) // minimum 2pt (Design.md)

                    Rectangle()
                        .fill(segmentFillColor(segment))
                        .frame(width: segmentWidth, height: geometry.size.height)
                        .offset(x: startFraction * totalWidth)
                        .onTapGesture {
                            HapticManager.segmentTap()
                            viewModel.seek(to: segment.startTime)
                        }
                        .onLongPressGesture {
                            viewModel.toggleSegment(segment)
                        }
                }

                // Playhead (Design.md: 2pt wide, Snow, full height + triangle cap)
                let playheadX = (viewModel.currentTime / totalDuration) * totalWidth
                VStack(spacing: 0) {
                    // Inverted triangle cap
                    Triangle()
                        .fill(Color.ccTextPrimary)
                        .frame(width: 8, height: 6)

                    // Vertical line
                    Rectangle()
                        .fill(Color.ccTextPrimary)
                        .frame(width: 2)
                }
                .offset(x: playheadX - 1) // center the 2pt line
                .animation(.linear(duration: 0.05), value: viewModel.currentTime)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Segment Color

    private func segmentFillColor(_ segment: Segment) -> Color {
        let isCurrentSegment = segment.contains(time: viewModel.currentTime)

        if segment.isIncluded {
            // Design.md: Rally Green full opacity, Rally Glow for active
            return isCurrentSegment ? Color.ccIncludeGlow : Color.ccInclude
        } else {
            // Design.md: Excluded = transparent (shows bar background)
            // Active excluded segment gets a faint outline effect
            return isCurrentSegment
                ? Color.ccTextTertiary.opacity(0.3)
                : Color.clear
        }
    }
}

// MARK: - Triangle Shape (for playhead cap)

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.closeSubpath()
        }
    }
}

// MARK: - Preview

#Preview {
    SegmentTimelineView()
        .frame(height: 48)
        .padding()
        .background(Color.ccBackground)
        .environment(PlayerViewModel())
}
