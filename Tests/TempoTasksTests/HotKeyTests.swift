import AppKit
import Carbon.HIToolbox
import XCTest
@testable import TempoTasks

final class HotKeyComboTests: XCTestCase {
    private func makeEvent(
        modifiers: NSEvent.ModifierFlags,
        keyCode: Int,
        characters: String = " "
    ) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: UInt16(keyCode)
        )!
    }

    func testDefaultIsControlCommandSpace() {
        let combo = HotKeyCombo.default
        XCTAssertEqual(combo.keyCode, UInt16(kVK_Space))
        XCTAssertNotEqual(combo.carbonModifiers & UInt32(controlKey), 0)
        XCTAssertNotEqual(combo.carbonModifiers & UInt32(cmdKey), 0)
        XCTAssertEqual(combo.displayString, "⌃⌘Space")
    }

    func testBuildsFromEventWithModifiers() {
        let event = makeEvent(modifiers: [.control, .command], keyCode: kVK_Space)
        let combo = HotKeyCombo(event: event)
        XCTAssertEqual(combo, .default)
    }

    func testRejectsEventWithoutRequiredModifier() {
        XCTAssertNil(HotKeyCombo(event: makeEvent(modifiers: [], keyCode: kVK_Space)))
        XCTAssertNil(HotKeyCombo(event: makeEvent(modifiers: [.shift], keyCode: kVK_Space)))
    }

    func testRejectsModifierOnlyKeyCode() {
        // 只按住 Control + Command 不构成可注册的热键，必须有主键。
        let event = makeEvent(modifiers: [.control, .command], keyCode: kVK_Command)
        XCTAssertNil(HotKeyCombo(event: event))
    }

    func testModifierSymbolsFollowMacOrder() {
        let event = makeEvent(modifiers: [.command, .shift, .option, .control], keyCode: kVK_Space)
        let combo = HotKeyCombo(event: event)
        XCTAssertEqual(combo?.displayString, "⌃⌥⇧⌘Space")
    }

    func testNamedKeysAreReadable() {
        XCTAssertEqual(HotKeyCombo.keyName(for: UInt16(kVK_Escape)), "esc")
        XCTAssertEqual(HotKeyCombo.keyName(for: UInt16(kVK_F5)), "F5")
        XCTAssertEqual(HotKeyCombo.keyName(for: UInt16(kVK_UpArrow)), "↑")
    }

    func testRoundTripsThroughCoding() throws {
        let original = HotKeyCombo(
            keyCode: UInt16(kVK_ANSI_T),
            carbonModifiers: UInt32(cmdKey | optionKey)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HotKeyCombo.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}

final class HotKeyStoreTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "TempoTasksTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testReturnsDefaultWhenNothingStored() {
        XCTAssertEqual(HotKeyStore(defaults: defaults).load(), .default)
    }

    func testSavesAndLoads() {
        let store = HotKeyStore(defaults: defaults)
        let combo = HotKeyCombo(
            keyCode: UInt16(kVK_ANSI_J),
            carbonModifiers: UInt32(controlKey | optionKey)
        )
        store.save(combo)
        XCTAssertEqual(HotKeyStore(defaults: defaults).load(), combo)
    }

    func testFallsBackToDefaultOnCorruptedData() {
        defaults.set(Data("not json".utf8), forKey: "TempoTasks.hotKeyCombo")
        XCTAssertEqual(HotKeyStore(defaults: defaults).load(), .default)
    }

    func testResetRestoresDefault() {
        let store = HotKeyStore(defaults: defaults)
        store.save(HotKeyCombo(keyCode: UInt16(kVK_ANSI_K), carbonModifiers: UInt32(cmdKey)))
        store.reset()
        XCTAssertEqual(store.load(), .default)
    }
}
