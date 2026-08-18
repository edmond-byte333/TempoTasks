import AppKit
import XCTest
@testable import TempoTasks

final class PanelPositionMemoryTests: XCTestCase {
    private let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)
    private let initial = NSRect(x: 340, y: 280, width: 760, height: 520)

    func testProgrammaticMoveDoesNotCreateStoredPosition() {
        var memory = PanelPositionMemory()

        let result = memory.endDrag(
            originalFrame: initial,
            currentFrame: initial.offsetBy(dx: 50, dy: 20),
            visibleFrames: [screen]
        )

        XCTAssertNil(result)
        XCTAssertNil(memory.storedFrame)
    }

    func testClickWithoutMovementDoesNotCreateStoredPosition() {
        var memory = PanelPositionMemory()
        memory.beginDrag(at: initial)

        let result = memory.endDrag(
            originalFrame: initial,
            currentFrame: initial,
            visibleFrames: [screen]
        )

        XCTAssertNil(result)
        XCTAssertNil(memory.storedFrame)
    }

    func testCompletedDragStoresConstrainedFrame() {
        var memory = PanelPositionMemory()
        memory.beginDrag(at: initial)
        let partiallyOffscreen = initial.offsetBy(dx: 900, dy: 300)

        let stored = memory.endDrag(
            originalFrame: initial,
            currentFrame: partiallyOffscreen,
            visibleFrames: [screen]
        )

        XCTAssertEqual(stored, NSRect(x: 680, y: 380, width: 760, height: 520))
        XCTAssertEqual(memory.storedFrame, stored)
    }

    func testStoredFrameIsInvalidatedWhenItsScreenDisappears() {
        var memory = PanelPositionMemory()
        memory.beginDrag(at: initial)
        _ = memory.endDrag(
            originalFrame: initial,
            currentFrame: initial.offsetBy(dx: 20, dy: 20),
            visibleFrames: [screen]
        )

        let differentScreen = NSRect(x: 2000, y: 0, width: 1200, height: 800)
        XCTAssertNil(memory.validStoredFrame(in: [differentScreen]))
        XCTAssertNil(memory.storedFrame)
    }

    func testDefaultFrameIsTopCenteredAndFullyVisible() {
        let frame = PanelPositionMemory.defaultFrame(
            panelSize: NSSize(width: 760, height: 520),
            in: screen
        )

        XCTAssertEqual(frame, NSRect(x: 340, y: 316, width: 760, height: 520))
        XCTAssertTrue(PanelPositionMemory.isFullyVisible(frame, in: [screen]))
    }
}

