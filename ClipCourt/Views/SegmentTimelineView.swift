// SegmentTimelineView.swift
// ClipCourt
//
// Mini-timeline showing included (Rally Green) vs excluded (dimmed) regions.
// Supports pinch-to-zoom (1x–10x), horizontal scrolling when zoomed,
// auto-follow playhead, and snap-to-overview. "I bent my Wookiee!" — but I
// never bend my timeline. It's pixel-perfect AND zoomable.

import SwiftUI

struct SegmentTimelineView: View {

    // MARK: - Environment

    @Environment(PlayerViewModel.self) private var viewModel

    // MARK: - Zoom State

    /// Current zoom level (1.0 = overview, 10.0 = max zoom)
    @State private var zoomScale: CGFloat = 1.0

    /// Zoom level at the start of a pinch gesture
    @State private var gestureStartZoom: CGFloat = 1.0

    /// Scroll offset in points (0 = left edge of timeline visible)
    @State private var scrollOffset: CGFloat = 0

    /// Whether the user is actively interacting (disables auto-follow)
    @State private var isUserInteracting: Bool = false

    /// Timer to re-enable auto-follow after user stops interacting
    @State private var autoFollowResumeTask: Task<Void, Never>?

    /// Whether the zoom level badge is visible
    @State private var showZoomBadge: Bool = false

    /// Task to hide the zoom badge after delay
    @State private var zoomBadgeHideTask: Task<Void, Never>?

    // MARK: - Constants

    private let minZoom: CGFloat = 1.0
    private let maxZoom: CGFloat = 10.0
    private let snapThreshold: CGFloat = 1.2
    private let autoFollowResumeDelay: Duration = .seconds(2)

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let containerWidth = geometry.size.width
            let containerHeight = geometry.size.height
            let totalDuration = max(viewModel.duration, 0.01)
            let contentWidth = containerWidth * zoomScale

            ZStack(alignment: .topLeading) {
                // --- Scrollable timeline content ---
                timelineContent(
                    containerWidth: containerWidth,
                    containerHeight: containerHeight,
                    contentWidth: contentWidth,
                    totalDuration: totalDuration
                )
                .frame(width: contentWidth, height: containerHeight)
                .offset(x: -scrollOffset)

                // --- Zoom level badge (shown during pinch) ---
                if showZoomBadge && zoomScale > 1.0 {
                    Text(String(format: "%.1fx", zoomScale))
                        .font(.caption2.bold())
                        .foregroundStyle(Color.ccTextSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.ccSurfaceElevated, in: Capsule())
                        .offset(y: -22) // Above the timeline
                        .frame(maxWidth: .infinity, alignment: .center)
                        .transition(.opacity)
                        .animation(.easeOut(duration: 0.2), value: showZoomBadge)
                }

                // --- Scroll position indicator (mini-map) when zoomed ---
                if zoomScale > 1.0 {
                    scrollIndicator(containerWidth: containerWidth, contentWidth: contentWidth)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
            // --- Pinch-to-zoom gesture ---
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        isUserInteracting = true
                        showZoomBadge = true
                        zoomBadgeHideTask?.cancel()

                        let newZoom = clamp(gestureStartZoom * value, min: minZoom, max: maxZoom)
                        let oldZoom = zoomScale

                        // Adjust scroll to keep the center point stable during zoom
                        let centerFraction = (scrollOffset + containerWidth / 2) / (containerWidth * oldZoom)
                        zoomScale = newZoom
                        let newContentWidth = containerWidth * newZoom
                        scrollOffset = clamp(
                            centerFraction * newContentWidth - containerWidth / 2,
                            min: 0,
                            max: max(newContentWidth - containerWidth, 0)
                        )
                    }
                    .onEnded { _ in
                        gestureStartZoom = zoomScale

                        // Snap-to-overview if below threshold
                        if zoomScale < snapThreshold {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                zoomScale = 1.0
                                scrollOffset = 0
                            }
                            gestureStartZoom = 1.0
                        }

                        // Hide zoom badge after 1 second
                        zoomBadgeHideTask = Task { @MainActor in
                            try? await Task.sleep(for: .seconds(1))
                            guard !Task.isCancelled else { return }
                            showZoomBadge = false
                        }

                        scheduleAutoFollowResume()
                    }
            )
            // --- Drag gesture for scrolling when zoomed ---
            .simultaneousGesture(
                zoomScale > 1.0 ?
                DragGesture()
                    .onChanged { value in
                        isUserInteracting = true
                        let maxOffset = max(contentWidth - containerWidth, 0)
                        scrollOffset = clamp(
                            scrollOffset - value.translation.width / 2,
                            min: 0,
                            max: maxOffset
                        )
                    }
                    .onEnded { _ in
                        scheduleAutoFollowResume()
                    }
                : nil
            )
            // --- Tap gesture to seek ---
            .onTapGesture { location in
                let tappedFraction = (scrollOffset + location.x) / contentWidth
                let tappedTime = tappedFraction * totalDuration
                HapticManager.segmentTap()
                viewModel.seek(to: clamp(tappedTime, min: 0, max: totalDuration))
            }
            // --- Auto-follow playhead during playback ---
            .onChange(of: viewModel.currentTime) { _, newTime in
                guard zoomScale > 1.0, !isUserInteracting, viewModel.isPlaying else { return }
                autoFollowPlayhead(
                    currentTime: newTime,
                    totalDuration: totalDuration,
                    containerWidth: containerWidth,
                    contentWidth: contentWidth
                )
            }
        }
    }

    // MARK: - Timeline Content

    private func timelineContent(
        containerWidth: CGFloat,
        containerHeight: CGFloat,
        contentWidth: CGFloat,
        totalDuration: Double
    ) -> some View {
        ZStack(alignment: .leading) {
            // Background bar (Design.md: ccSurface, 8pt corner radius)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.ccSurface)

            // Segment blocks
            ForEach(viewModel.segments) { segment in
                let startFraction = segment.startTime / totalDuration
                let durationFraction = segment.duration / totalDuration
                let segmentWidth = max(durationFraction * contentWidth, 2)
                let segmentX = startFraction * contentWidth

                Rectangle()
                    .fill(segmentFillColor(segment))
                    .frame(width: segmentWidth, height: containerHeight)
                    .offset(x: segmentX)
                    // Border separators when zoomed (Design.md)
                    .overlay(alignment: .trailing) {
                        if zoomScale > 2.0 {
                            Rectangle()
                                .fill(Color.ccSurface)
                                .frame(width: 0.5)
                        }
                    }
                    .onLongPressGesture {
                        viewModel.toggleSegment(segment)
                    }
            }

            // Playhead (Design.md: 2pt wide, Snow, full height + triangle cap)
            let playheadX = (viewModel.currentTime / totalDuration) * contentWidth
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
    }

    // MARK: - Scroll Position Indicator (Mini-map)

    private func scrollIndicator(containerWidth: CGFloat, contentWidth: CGFloat) -> some View {
        let visibleFraction = containerWidth / contentWidth
        let offsetFraction = scrollOffset / max(contentWidth - containerWidth, 1)
        let indicatorWidth = max(containerWidth * visibleFraction, 20)
        let indicatorX = (containerWidth - indicatorWidth) * offsetFraction

        return Rectangle()
            .fill(Color.ccTextSecondary.opacity(0.4))
            .frame(width: indicatorWidth, height: 2)
            .cornerRadius(1)
            .offset(x: indicatorX)
            .padding(.bottom, 1)
    }

    // MARK: - Auto-Follow Playhead

    private func autoFollowPlayhead(
        currentTime: Double,
        totalDuration: Double,
        containerWidth: CGFloat,
        contentWidth: CGFloat
    ) {
        let playheadX = (currentTime / totalDuration) * contentWidth
        // Keep playhead at 40% from leading edge (Design.md: show upcoming content)
        let targetOffset = playheadX - containerWidth * 0.4
        let maxOffset = max(contentWidth - containerWidth, 0)
        let clampedOffset = clamp(targetOffset, min: 0, max: maxOffset)

        withAnimation(.linear(duration: 0.1)) {
            scrollOffset = clampedOffset
        }
    }

    // MARK: - Auto-Follow Resume

    private func scheduleAutoFollowResume() {
        autoFollowResumeTask?.cancel()
        autoFollowResumeTask = Task { @MainActor in
            try? await Task.sleep(for: autoFollowResumeDelay)
            guard !Task.isCancelled else { return }
            isUserInteracting = false
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

    // MARK: - Helpers

    private func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, min), max)
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
