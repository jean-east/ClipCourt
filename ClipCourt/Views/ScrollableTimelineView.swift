// ScrollableTimelineView.swift
// ClipCourt
//
// LumaFusion-style scrollable timeline with fixed centered playhead.
// UIScrollView-based for precise contentOffset control during playback.
//
// Polished: UIHostingController (App Store safe), UIPinchGestureRecognizer,
// scroll-to-seek, auto-follow, UILongPressGestureRecognizer for segment toggle.

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
        .clipped()
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
                pointsPerSecond: $pointsPerSecond,
                minPointsPerSecond: minPointsPerSecond,
                maxPointsPerSecond: maxPointsPerSecond,
                onScrollEnded: { handleScrollEnded() },
                onLongPress: { time in handleLongPress(at: time) },
                content: {
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
                .allowsHitTesting(false)

        }
        .background(Color.ccBackground)
        .onAppear { computeInitialScale() }
        .onChange(of: viewModel.duration) { _, _ in computeInitialScale() }
        .onChange(of: viewModel.currentTime) { _, newTime in
            if !isUserDragging {
                autoFollowPlayhead(time: CGFloat(newTime))
            }
        }
    }

    // MARK: - Scale computation

    private func computeInitialScale() {
        guard containerSize.width > 0, totalDuration > 0.01 else { return }
        // Min: entire video fits
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

    // MARK: - Long-press → toggle segment at press location

    private func handleLongPress(at time: CGFloat) {
        let clampedTime = Double(min(max(time, 0), totalDuration))
        if let segment = viewModel.segments.first(where: { seg in
            seg.contains(time: clampedTime) && seg.isIncluded
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

// MARK: - Segment Canvas

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
            let videoEndX = size.width - edgePadding

            // -- Video region: lighter background --
            let videoRect = CGRect(x: edgePadding, y: 0,
                                   width: videoEndX - edgePadding, height: size.height)
            context.fill(Path(videoRect), with: .color(Color.ccSurface))

            // -- Boundary separator lines (subtle 1pt vertical markers) --
            let startLine = CGRect(x: edgePadding - 0.5, y: 0,
                                   width: 1, height: size.height)
            context.fill(Path(startLine), with: .color(Color.ccTextTertiary.opacity(0.3)))

            let endLine = CGRect(x: videoEndX - 0.5, y: 0,
                                 width: 1, height: size.height)
            context.fill(Path(endLine), with: .color(Color.ccTextTertiary.opacity(0.3)))

            // -- Segments --
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

// MARK: - Time Ruler

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

// MARK: - UIScrollView Wrapper

/// UIViewRepresentable wrapping UIScrollView for precise contentOffset control.
/// Uses UIHostingController (App Store safe) instead of private _UIHostingView.
struct TimelineScrollView<Content: View>: UIViewRepresentable {

    let contentWidth: CGFloat
    let containerWidth: CGFloat
    @Binding var scrollOffset: CGFloat
    @Binding var isUserDragging: Bool
    @Binding var pointsPerSecond: CGFloat
    let minPointsPerSecond: CGFloat
    let maxPointsPerSecond: CGFloat
    let onScrollEnded: () -> Void
    let onLongPress: (_ time: CGFloat) -> Void
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

        // Host the SwiftUI content via UIHostingController (App Store safe)
        let hostView = context.coordinator.hostingController.view!
        hostView.backgroundColor = .clear
        scrollView.addSubview(hostView)

        // Pinch-to-zoom gesture (replaces SwiftUI MagnifyGesture to avoid
        // conflicts with UIScrollView scrolling)
        let pinch = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        scrollView.addGestureRecognizer(pinch)

        // Long-press gesture for segment toggling
        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.5
        scrollView.addGestureRecognizer(longPress)

        context.coordinator.scrollView = scrollView

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        // Keep coordinator's parent reference current
        context.coordinator.parent = self

        // Update content size
        scrollView.contentSize = CGSize(width: contentWidth, height: scrollView.bounds.height)

        // Update hosted SwiftUI content
        let hostingController = context.coordinator.hostingController
        hostingController.rootView = AnyView(
            VStack(spacing: 0) {
                content()
            }
        )
        hostingController.view.frame = CGRect(
            x: 0, y: 0,
            width: contentWidth,
            height: scrollView.bounds.height
        )

        // Sync scroll position from SwiftUI → UIKit (during playback / pinch)
        // Only when user is NOT actively dragging
        if !context.coordinator.isDragging {
            let targetX = scrollOffset
            if abs(scrollView.contentOffset.x - targetX) > 0.5 {
                scrollView.contentOffset.x = targetX
            }
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: TimelineScrollView
        var isDragging = false
        let hostingController: UIHostingController<AnyView>
        weak var scrollView: UIScrollView?

        /// Stores the pointsPerSecond at pinch start for anchored zoom
        private var pinchBasePPS: CGFloat = 1
        /// Stores the scroll offset at pinch start
        private var pinchBaseOffset: CGFloat = 0

        init(parent: TimelineScrollView) {
            self.parent = parent
            self.hostingController = UIHostingController(rootView: AnyView(EmptyView()))
            super.init()
            // Transparent background so timeline shows through
            self.hostingController.view.backgroundColor = .clear
        }

        // MARK: - UIScrollViewDelegate

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

        // MARK: - Pinch-to-Zoom (anchored at playhead)

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let scrollView = scrollView else { return }

            switch gesture.state {
            case .began:
                pinchBasePPS = parent.pointsPerSecond
                pinchBaseOffset = scrollView.contentOffset.x

            case .changed:
                let newPPS = min(
                    max(pinchBasePPS * gesture.scale, parent.minPointsPerSecond),
                    parent.maxPointsPerSecond
                )

                // Anchor zoom at playhead (center of screen).
                // Time at playhead = scrollOffset / oldPPS
                // New offset = timeAtPlayhead * newPPS
                let timeAtPlayhead = pinchBaseOffset / pinchBasePPS
                let newOffset = timeAtPlayhead * newPPS

                // Compute new content width for immediate UIKit update
                // (avoids contentOffset clamping before SwiftUI layout pass)
                let totalDuration = (parent.contentWidth - parent.containerWidth)
                    / parent.pointsPerSecond
                let newContentWidth = totalDuration * newPPS + parent.containerWidth

                // Update UIKit immediately for responsive feel
                scrollView.contentSize.width = newContentWidth
                scrollView.contentOffset.x = newOffset

                // Update bindings (triggers SwiftUI state change → body recompute)
                DispatchQueue.main.async {
                    self.parent.pointsPerSecond = newPPS
                    self.parent.scrollOffset = newOffset
                }

            case .ended, .cancelled:
                // Snap to overview if close to minimum zoom
                let currentPPS = parent.pointsPerSecond
                let minPPS = parent.minPointsPerSecond
                if currentPPS < minPPS * 1.15 {
                    let totalDuration = (parent.contentWidth - parent.containerWidth)
                        / currentPPS
                    let timeAtPlayhead = parent.scrollOffset / currentPPS
                    let snappedOffset = timeAtPlayhead * minPPS
                    let snappedWidth = totalDuration * minPPS + parent.containerWidth

                    scrollView.contentSize.width = snappedWidth

                    DispatchQueue.main.async {
                        self.parent.pointsPerSecond = minPPS
                        self.parent.scrollOffset = snappedOffset
                    }

                    UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
                        scrollView.contentOffset.x = snappedOffset
                    }
                }

            default:
                break
            }
        }

        // MARK: - Long-Press → Toggle Segment

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began, let scrollView = scrollView else { return }

            // gesture.location(in: scrollView) returns content-space coordinates
            // (UIScrollView's coordinate system is its content space)
            let contentX = gesture.location(in: scrollView).x
            let edgePadding = parent.containerWidth / 2
            let time = (contentX - edgePadding) / parent.pointsPerSecond

            DispatchQueue.main.async {
                self.parent.onLongPress(time)
            }
        }
    }
}
