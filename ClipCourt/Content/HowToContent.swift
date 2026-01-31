// HowToContent.swift
// ClipCourt
//
// Edit the how-to tips here — no need to touch view code.

import Foundation

struct HowToTip {
    let icon: String
    let text: String
}

enum HowToContent {
    static let tips: [HowToTip] = [
        HowToTip(icon: "video.badge.plus",
                 text: "Tap \"Choose Video\" to pick a game from your camera roll"),
        HowToTip(icon: "hand.tap",
                 text: "Tap \"Tap to Keep\" while watching — tap again to stop"),
        HowToTip(icon: "checkmark.circle.fill",
                 text: "Green = highlights you're keeping · Dark = parts that get skipped"),
        HowToTip(icon: "arrow.up.left.and.arrow.down.right",
                 text: "Scroll the timeline to scrub · Pinch to zoom in for precision"),
        HowToTip(icon: "slider.horizontal.3",
                 text: "Drag the seek bar to jump to any point in the video"),
        HowToTip(icon: "hand.tap.fill",
                 text: "Long-press a green clip on the timeline to remove it"),
        HowToTip(icon: "forward.fill",
                 text: "Long-press the video to fast-forward at your chosen speed"),
        HowToTip(icon: "square.and.arrow.up",
                 text: "Tap Export to save your highlight reel to Camera Roll 🏐"),
    ]
}
