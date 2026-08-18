import AppKit
import SwiftUI

struct WindowDragSurface: NSViewRepresentable {
    let onDragBegan: () -> Void
    let onDragEnded: (NSRect, NSRect) -> Void

    func makeNSView(context: Context) -> WindowDragNSView {
        let view = WindowDragNSView()
        view.onDragBegan = onDragBegan
        view.onDragEnded = onDragEnded
        return view
    }

    func updateNSView(_ nsView: WindowDragNSView, context: Context) {
        nsView.onDragBegan = onDragBegan
        nsView.onDragEnded = onDragEnded
    }
}

final class WindowDragNSView: NSView {
    var onDragBegan: (() -> Void)?
    var onDragEnded: ((NSRect, NSRect) -> Void)?

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let originalFrame = window.frame
        onDragBegan?()
        window.performDrag(with: event)
        onDragEnded?(originalFrame, window.frame)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func isAccessibilityElement() -> Bool {
        false
    }
}

