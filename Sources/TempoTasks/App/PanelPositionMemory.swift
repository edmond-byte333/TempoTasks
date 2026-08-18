import AppKit

struct PanelPositionMemory {
    private(set) var storedFrame: NSRect?
    private var dragOrigin: NSRect?

    mutating func beginDrag(at frame: NSRect) {
        dragOrigin = frame
    }

    mutating func endDrag(
        originalFrame: NSRect,
        currentFrame: NSRect,
        visibleFrames: [NSRect]
    ) -> NSRect? {
        guard let dragOrigin else { return nil }
        self.dragOrigin = nil

        guard NSEqualRects(dragOrigin, originalFrame),
              !NSEqualRects(originalFrame, currentFrame),
              let constrained = Self.constrainedFrame(currentFrame, to: visibleFrames)
        else {
            return nil
        }

        storedFrame = constrained
        return constrained
    }

    mutating func validStoredFrame(in visibleFrames: [NSRect]) -> NSRect? {
        guard let storedFrame else { return nil }
        guard Self.isFullyVisible(storedFrame, in: visibleFrames) else {
            self.storedFrame = nil
            return nil
        }
        return storedFrame
    }

    static func defaultFrame(
        panelSize: NSSize,
        in visibleFrame: NSRect,
        topOffset: CGFloat = 64
    ) -> NSRect {
        let proposed = NSRect(
            x: visibleFrame.midX - panelSize.width / 2,
            y: visibleFrame.maxY - panelSize.height - topOffset,
            width: panelSize.width,
            height: panelSize.height
        )
        return constrainedFrame(proposed, to: [visibleFrame]) ?? proposed
    }

    static func isFullyVisible(_ frame: NSRect, in visibleFrames: [NSRect]) -> Bool {
        visibleFrames.contains { visibleFrame in
            visibleFrame.insetBy(dx: -0.5, dy: -0.5).contains(frame)
        }
    }

    static func constrainedFrame(_ frame: NSRect, to visibleFrames: [NSRect]) -> NSRect? {
        guard let target = bestVisibleFrame(for: frame, among: visibleFrames) else { return nil }

        let x: CGFloat
        if frame.width <= target.width {
            x = min(max(frame.minX, target.minX), target.maxX - frame.width)
        } else {
            x = target.minX
        }

        let y: CGFloat
        if frame.height <= target.height {
            y = min(max(frame.minY, target.minY), target.maxY - frame.height)
        } else {
            y = target.minY
        }

        return NSRect(origin: NSPoint(x: x, y: y), size: frame.size)
    }

    private static func bestVisibleFrame(for frame: NSRect, among visibleFrames: [NSRect]) -> NSRect? {
        visibleFrames.max { first, second in
            intersectionArea(of: frame, and: first) < intersectionArea(of: frame, and: second)
        }
    }

    private static func intersectionArea(of first: NSRect, and second: NSRect) -> CGFloat {
        let intersection = first.intersection(second)
        guard !intersection.isNull else { return 0 }
        return intersection.width * intersection.height
    }
}

