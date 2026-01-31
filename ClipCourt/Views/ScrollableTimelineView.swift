// ScrollableTimelineView.swift
// ClipCourt
//
// LumaFusion-style scrollable timeline with fixed centered playhead.
// UIScrollView-based for precise contentOffset control during playback.

import SwiftUI

// MARK: - Public SwiftUI Entry Point

/// Drop-in replacement for SegmentTimelineView.
/// Usage: `ScrollableTimelineView().environment(viewModel)`
struct ScrollableTimelineView: View {

    @Environment(PlayerViewModel.self) private var viewModel

    var body: some View {
        GeometryReader { geometry in
            TimelineContainer(
                viewModel: viewModel,
                containerSize: geometry.size
            )
        }
        .frame(height: Constants.UI.timelineHeight)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Timeline Container (coordinates UIKit + SwiftUI overlay)

/// Layers the UIScrollView, Canvas segments, time ruler, and fixed playhead.
private struct TimelineContainer: View {

    let viewModel: PlayerViewModel
    let containerSize: CGSize

    /// Points per second — determines zoom level. Higher = more zoomed in.
    @State private var pointsPerSecond: CGFloat = 1 // computed on appear
    @State private var minPointsPerSecond: CGFloat = 1
    @State private var maxPointsPerSecond: CGFloat = 100

    /// Current scroll offset in points (set by UIScrollView delegate)
    @State private var scrollOffset: CGFloat = 0

    /// Whether the user is actively dragging (disables auto-follow)
    @State private var isUserDragging: Bool = false

    /// Pinch gesture base scale
    @State private var pinchBaseScale: CGFloat = 1

    private var totalDuration: CGFloat { max(CGFloat(viewModel.duration), 0.01) }
    private var edgePadding: CGFloat { containerSize.width / 2 }
    private var contentWidth: CGFloat { totalDuration * pointsPerSecond + containerSize.width }

    var body: some View {
        ZStack {
            // Layer 1: Scrollable content (segments + time ruler)
            TimelineScrollView(
                contentWidth: contentWidth,
                containerWidth: containerSize.width,
                scrollOffset: $scrollOffset,
                isUserDragging: $isUserDragging,
                onScrollEnded: { handleScrollEnded() },
                content: {
                    // ENGINEER A: Implement Canvas segment rendering
                    // - Draw in a coordinate space where x=0 is the left edge padding
                    // - Segment x position = edgePadding + segment.startTime * pointsPerSecond
                    // - Segment width = segment.duration * pointsPerSecond
                    // - Green (ccInclude) for included, skip excluded
                    // - During active keep: draw green from keepStart to currentTime
                    // - Only draw segments visible in the current viewport
                    SegmentCanvasView(
                        segments: viewModel.segments,
                        isIncluding: viewModel.isIncluding,
                        keepingStartTime: viewModel.keepingStartTime,
                        currentTime: CGFloat(viewModel.currentTime),
                        pointsPerSecond: pointsPerSecond,
                        edgePadding: edgePadding,
                        totalHeight: containerSize.height,
                        scrollOffset: scrollOffset,
                        viewportWidth: containerSize.width
                    )
                    .frame(width: contentWidth, height: containerSize.height - 18)

                    // ENGINEER B: Implement time ruler
                    // - Positioned at bottom of timeline
                    // - Adaptive ticks based on pointsPerSecond
                    // - Labels in ccTextTertiary, monospaced 9pt
                    TimeRulerView(
                        totalDuration: totalDuration,
                        pointsPerSecond: pointsPerSecond,
                        edgePadding: edgePadding,
                        contentWidth: contentWidth,
                        scrollOffset: scrollOffset,
                        viewportWidth: containerSize.width
                    )
                    .frame(width: contentWidth, height: 18)
                }
            )

            // Layer 2: Fixed centered playhead (never scrolls)
            PlayheadView()
                .frame(width: 8, height: containerSize.height)
                .position(x: containerSize.width / 2, y: containerSize.height / 2)

        }
        .background(Color.ccSurface)
        .onAppear { computeInitialScale() }
        .onChange(of: viewModel.duration) { _, _ in computeInitialScale() }
        .onChange(of: viewModel.currentTime) { _, newTime in
            if !isUserDragging {
                autoFollowPlayhead(time: CGFloat(newTime))
            }
        }
        .gesture(pinchGesture)
        // Long-press for segment deletion
        .onLongPressGesture {
            handleLongPress()
        }
    }

    // MARK: - Scale computation

    private func computeInitialScale() {
        guard containerSize.width > 0, totalDuration > 0.01 else { return }
        // Min: entire video fits (minus edge padding)
        minPointsPerSecond = containerSize.width / totalDuration
        // Max: ~5 seconds fills the screen
        maxPointsPerSecond = containerSize.width / 5.0
        // Start at overview
        pointsPerSecond = minPointsPerSecond
    }

    // MARK: - Auto-follow playhead during playback

    private func autoFollowPlayhead(time: CGFloat) {
        let targetOffset = time * pointsPerSecond
        scrollOffset = targetOffset
    }

    // MARK: - Scroll ended → seek

    private func handleScrollEnded() {
        let time = scrollOffset / pointsPerSecond
        let clampedTime = min(max(time, 0), totalDuration)
        viewModel.seek(to: Double(clampedTime))
    }

    // MARK: - Pinch-to-zoom

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let newScale = pinchBaseScale * value.magnification
                pointsPerSecond = min(max(newScale, minPointsPerSecond), maxPointsPerSecond)
                // Keep the same time under the playhead
                let timeAtPlayhead = scrollOffset / (pinchBaseScale * (value.magnification - 1 + 1))
                scrollOffset = timeAtPlayhead * pointsPerSecond
            }
            .onEnded { _ in
                pinchBaseScale = pointsPerSecond
                // Snap to overview if close
                if pointsPerSecond < minPointsPerSecond * 1.15 {
                    withAnimation(.easeOut(duration: 0.2)) {
                        pointsPerSecond = minPointsPerSecond
                    }
                }
            }
    }

    // MARK: - Long-press → delete segment

    private func handleLongPress() {
        let timeAtPlayhead = scrollOffset / pointsPerSecond
        // Find the segment at the playhead position
        if let segment = viewModel.segments.first(where: { seg in
            seg.contains(time: Double(timeAtPlayhead)) && seg.isIncluded
        }) {
            viewModel.toggleSegment(segment)
        }
    }
}

// MARK: - Playhead (fixed centered overlay)

/// The fixed vertical playhead line with a downward triangle at top.
private struct PlayheadView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Downward triangle
            Triangle()
                .fill(Color.white)
                .frame(width: 8, height: 6)
            // Vertical line
            Rectangle()
                .fill(Color.white)
                .frame(width: 2)
        }
    }
}

// Reuses Triangle shape from SegmentTimelineView.swift

// MARK: - Segment Canvas (ENGINEER A fills this in)

/// Canvas-based segment renderer for performance.
/// Draws green rectangles for included segments, skips excluded.
struct SegmentCanvasView: View {

    let segments: [Segment]
    let isIncluding: Bool
    let keepingStartTime: Double?
    let currentTime: CGFloat
    let pointsPerSecond: CGFloat
    let edgePadding: CGFloat
    let totalHeight: CGFloat
    let scrollOffset: CGFloat
    let viewportWidth: CGFloat

    var body: some View {
        Canvas { context, size in
            let visibleStart = scrollOffset - edgePadding
            let visibleEnd = visibleStart + viewportWidth

            for segment in segments {
                guard segment.isIncluded else { continue }

                let x = edgePadding + CGFloat(segment.startTime) * pointsPerSecond
                let w = CGFloat(segment.duration) * pointsPerSecond
                let segEnd = x + w

                // Viewport culling
                guard segEnd > visibleStart, x < visibleEnd + edgePadding else { continue }

                let rect = CGRect(x: x, y: 0, width: max(w, 2), height: size.height)
                context.fill(Path(rect), with: .color(Color.ccInclude))
            }

            // Active keep: draw growing green from keepStart to currentTime
            if isIncluding, let keepStart = keepingStartTime {
                let x = edgePadding + CGFloat(keepStart) * pointsPerSecond
                let w = (currentTime - CGFloat(keepStart)) * pointsPerSecond
                if w > 0 {
                    let rect = CGRect(x: x, y: 0, width: w, height: size.height)
                    context.fill(Path(rect), with: .color(Color.ccInclude))
                }
            }
        }
    }
}

// MARK: - Time Ruler (ENGINEER B fills this in)

/// Adaptive time ruler at the bottom of the timeline.
struct TimeRulerView: View {

    let totalDuration: CGFloat
    let pointsPerSecond: CGFloat
    let edgePadding: CGFloat
    let contentWidth: CGFloat
    let scrollOffset: CGFloat
    let viewportWidth: CGFloat

    /// Compute adaptive tick interval based on zoom level
    private var majorTickInterval: CGFloat {
        let pixelsPerTick: CGFloat = 80 // aim for ~80pt between major ticks
        let secondsPerTick = pixelsPerTick / pointsPerSecond
        // Snap to clean intervals
        let candidates: [CGFloat] = [1, 2, 5, 10, 15, 30, 60, 120, 300, 600]
        return candidates.first(where: { $0 >= secondsPerTick }) ?? 600
    }

    var body: some View {
        Canvas { context, size in
            let interval = majorTickInterval
            let visibleStart = max(0, (scrollOffset - edgePadding) / pointsPerSecond)
            let visibleEnd = visibleStart + viewportWidth / pointsPerSecond
            let firstTick = floor(visibleStart / interval) * interval

            var t = firstTick
            while t <= min(visibleEnd + interval, totalDuration) {
                let x = edgePadding + t * pointsPerSecond

                // Major tick line
                let tickPath = Path(CGRect(x: x - 0.5, y: 0, width: 1, height: 6))
                context.fill(tickPath, with: .color(Color.ccTextTertiary.opacity(0.6)))

                // Label
                let label = formatTime(t)
                let text = Text(label)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color.ccTextTertiary)
                context.draw(text, at: CGPoint(x: x, y: 12))

                t += interval
            }
        }
    }

    private func formatTime(_ seconds: CGFloat) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, secs)
        } else {
            return String(format: "0:%02d", secs)
        }
    }
}

// MARK: - UIScrollView Wrapper (ENGINEER C fills this in)

/// UIViewRepresentable wrapping UIScrollView for precise contentOffset control.
struct TimelineScrollView<Content: View>: UIViewRepresentable {

    let contentWidth: CGFloat
    let containerWidth: CGFloat
    @Binding var scrollOffset: CGFloat
    @Binding var isUserDragging: Bool
    let onScrollEnded: () -> Void
    @ViewBuilder let content: () -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.delegate = context.coordinator
        scrollView.decelerationRate = .normal

        // Host the SwiftUI content
        let hostView = context.coordinator.hostView
        scrollView.addSubview(hostView)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        // Update content size
        scrollView.contentSize = CGSize(width: contentWidth, height: scrollView.bounds.height)

        // Update hosted SwiftUI content
        let hostView = context.coordinator.hostView
        hostView.rootView = AnyView(
            VStack(spacing: 0) {
                content()
            }
        )
        hostView.frame = CGRect(x: 0, y: 0, width: contentWidth, height: scrollView.bounds.height)

        // Sync scroll position from SwiftUI → UIKit (during playback)
        if !context.coordinator.isDragging {
            let targetX = scrollOffset
            if abs(scrollView.contentOffset.x - targetX) > 1 {
                scrollView.contentOffset.x = targetX
            }
        }
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        let parent: TimelineScrollView
        var isDragging = false
        let hostView: _UIHostingView<AnyView>

        init(parent: TimelineScrollView) {
            self.parent = parent
            self.hostView = _UIHostingView(rootView: AnyView(EmptyView()))
            super.init()
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            isDragging = true
            DispatchQueue.main.async {
                self.parent.isUserDragging = true
            }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if isDragging {
                DispatchQueue.main.async {
                    self.parent.scrollOffset = scrollView.contentOffset.x
                }
            }
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                endDrag()
            }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            endDrag()
        }

        private func endDrag() {
            isDragging = false
            DispatchQueue.main.async {
                self.parent.isUserDragging = false
                self.parent.onScrollEnded()
            }
        }
    }
}
