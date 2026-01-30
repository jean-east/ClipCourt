// SlideToKeepView.swift
// ClipCourt
//
// A "slide to unlock"–style toggle for the keeping UI.
// Horizontal pill track with a draggable thumb — slide right to keep, slide left to stop.

import SwiftUI

struct SlideToKeepView: View {

    // MARK: - Inputs

    let isOn: Bool
    let height: CGFloat
    let onToggle: () -> Void

    // MARK: - State

    /// Current drag offset (0 = resting position for current state).
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false

    // MARK: - Constants

    private let thumbPadding: CGFloat = 4
    private var thumbSize: CGFloat { height - thumbPadding * 2 }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let trackWidth = geo.size.width
            let maxSlide = trackWidth - thumbSize - thumbPadding * 2

            ZStack {
                // ── Track background ──
                trackBackground

                // ── Label text ──
                trackLabel(trackWidth: trackWidth)

                // ── Draggable thumb ──
                thumb(maxSlide: maxSlide)
            }
            .frame(height: height)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isOn ? Color.ccInclude.opacity(0.6) : Color.ccExclude.opacity(0.5),
                        lineWidth: isOn ? 2 : 1.5
                    )
            )
            .shadow(
                color: isOn ? Color.ccInclude.opacity(0.35) : .clear,
                radius: 8
            )
            .contentShape(Capsule())
            .onTapGesture {
                onToggle()
            }
        }
        .frame(height: height)
        .animation(.spring(response: 0.45, dampingFraction: 0.72), value: isOn)
    }

    // MARK: - Track Background

    private var trackBackground: some View {
        Capsule()
            .fill(isOn ? Color.ccInclude.opacity(0.2) : Color.ccSurface)
    }

    // MARK: - Track Label

    private func trackLabel(trackWidth: CGFloat) -> some View {
        ZStack {
            if isOn {
                Text("KEEPING")
                    .font(.subheadline.bold())
                    .tracking(2)
                    .foregroundStyle(Color.ccInclude)
                    .transition(.opacity)
            } else {
                ShimmerText("SLIDE TO START KEEPING →")
                    .transition(.opacity)
            }
        }
        // Offset text away from thumb so it's not occluded
        .offset(x: isOn ? -(thumbSize / 2 + thumbPadding) / 2 : (thumbSize / 2 + thumbPadding) / 2)
        .animation(.easeInOut(duration: 0.25), value: isOn)
    }

    // MARK: - Thumb

    private func thumb(maxSlide: CGFloat) -> some View {
        HStack {
            if isOn {
                Spacer(minLength: 0)
            }

            let clampedOffset: CGFloat = {
                if isOn {
                    // ON: thumb at right, drag left (negative offset) to toggle off
                    return min(0, max(-maxSlide, dragOffset))
                } else {
                    // OFF: thumb at left, drag right (positive offset) to toggle on
                    return max(0, min(maxSlide, dragOffset))
                }
            }()

            RoundedRectangle(cornerRadius: thumbSize / 2)
                .fill(isOn ? Color.ccInclude : Color.ccSurfaceElevated)
                .frame(width: thumbSize, height: thumbSize)
                .overlay(
                    Image(systemName: isOn ? "checkmark" : "chevron.right")
                        .font(.system(size: thumbSize * 0.35, weight: .bold))
                        .foregroundStyle(isOn ? Color.ccTextPrimary : Color.ccTextSecondary)
                )
                .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
                .offset(x: clampedOffset)
                .gesture(
                    DragGesture(minimumDistance: 4)
                        .onChanged { value in
                            isDragging = true
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            isDragging = false
                            let threshold = maxSlide * 0.45
                            if isOn {
                                // Must drag left past threshold to toggle off
                                if -value.translation.width > threshold || -value.predictedEndTranslation.width > maxSlide * 0.6 {
                                    onToggle()
                                }
                            } else {
                                // Must drag right past threshold to toggle on
                                if value.translation.width > threshold || value.predictedEndTranslation.width > maxSlide * 0.6 {
                                    onToggle()
                                }
                            }
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                dragOffset = 0
                            }
                        }
                )

            if !isOn {
                Spacer(minLength: 0)
            }
        }
        .padding(thumbPadding)
        .animation(isDragging ? nil : .spring(response: 0.45, dampingFraction: 0.72), value: dragOffset)
    }
}

// MARK: - Shimmer Text (iOS slide-to-unlock style)

/// Fading shimmer that sweeps across the text, like the classic iOS lock screen.
private struct ShimmerText: View {
    let text: String
    @State private var phase: CGFloat = -1

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.subheadline.bold())
            .tracking(2)
            .foregroundStyle(Color.ccTextSecondary.opacity(0.5))
            .overlay(
                GeometryReader { geo in
                    let w = geo.size.width
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.ccTextSecondary.opacity(0.9),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: w * 0.45)
                    .offset(x: phase * (w * 0.8))
                    .frame(width: w, alignment: .leading)
                }
                .mask(
                    Text(text)
                        .font(.subheadline.bold())
                        .tracking(2)
                )
            )
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1.5
                }
            }
    }
}

// MARK: - Preview

#Preview("OFF State") {
    VStack(spacing: 20) {
        SlideToKeepView(isOn: false, height: 72, onToggle: {})
        SlideToKeepView(isOn: true, height: 72, onToggle: {})
        SlideToKeepView(isOn: false, height: 48, onToggle: {})
        SlideToKeepView(isOn: true, height: 48, onToggle: {})
    }
    .padding()
    .background(Color.black)
}
