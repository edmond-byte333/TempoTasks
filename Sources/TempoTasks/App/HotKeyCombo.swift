import AppKit
import Carbon.HIToolbox

/// 一个全局快捷键组合：一个主键加上若干修饰键。
///
/// macOS 的 `RegisterEventHotKey` 必须有实体主键，纯修饰键组合（例如只按
/// Control + Command）注册不了，所以 `keyCode` 不可省略。
struct HotKeyCombo: Equatable, Codable, Sendable {
    /// Carbon / AppKit 共用的 virtual key code。
    let keyCode: UInt16
    /// Carbon 修饰键掩码（`controlKey`、`cmdKey`、`optionKey`、`shiftKey`）。
    let carbonModifiers: UInt32

    static let `default` = HotKeyCombo(
        keyCode: UInt16(kVK_Space),
        carbonModifiers: UInt32(controlKey | cmdKey)
    )

    init(keyCode: UInt16, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }

    // MARK: - 从按键事件构造

    /// 修饰键不足或主键本身就是修饰键时返回 nil。
    init?(event: NSEvent) {
        guard !Self.modifierKeyCodes.contains(event.keyCode) else { return nil }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var carbon: UInt32 = 0
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }

        // 只有 Shift 或没有修饰键时，普通打字会误触发全局热键。
        let required = UInt32(controlKey) | UInt32(cmdKey) | UInt32(optionKey)
        guard carbon & required != 0 else { return nil }

        self.init(keyCode: event.keyCode, carbonModifiers: carbon)
    }

    // MARK: - 显示

    /// 例如 "⌃⌘Space"。修饰键按 macOS 惯例排序：⌃⌥⇧⌘。
    var displayString: String {
        var result = ""
        if carbonModifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { result += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { result += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { result += "⌘" }
        result += Self.keyName(for: keyCode)
        return result
    }

    /// 供 VoiceOver 使用的读法。
    var accessibilityDescription: String {
        var parts: [String] = []
        if carbonModifiers & UInt32(controlKey) != 0 { parts.append("Control") }
        if carbonModifiers & UInt32(optionKey) != 0 { parts.append("Option") }
        if carbonModifiers & UInt32(shiftKey) != 0 { parts.append("Shift") }
        if carbonModifiers & UInt32(cmdKey) != 0 { parts.append("Command") }
        parts.append(Self.keyName(for: keyCode))
        return parts.joined(separator: " 加 ")
    }

    // MARK: - 键位表

    private static let modifierKeyCodes: Set<UInt16> = [
        UInt16(kVK_Command), UInt16(kVK_RightCommand),
        UInt16(kVK_Shift), UInt16(kVK_RightShift),
        UInt16(kVK_Option), UInt16(kVK_RightOption),
        UInt16(kVK_Control), UInt16(kVK_RightControl),
        UInt16(kVK_CapsLock), UInt16(kVK_Function)
    ]

    private static let namedKeys: [UInt16: String] = [
        UInt16(kVK_Space): "Space",
        UInt16(kVK_Return): "↩",
        UInt16(kVK_Tab): "⇥",
        UInt16(kVK_Escape): "esc",
        UInt16(kVK_Delete): "⌫",
        UInt16(kVK_ForwardDelete): "⌦",
        UInt16(kVK_LeftArrow): "←",
        UInt16(kVK_RightArrow): "→",
        UInt16(kVK_UpArrow): "↑",
        UInt16(kVK_DownArrow): "↓",
        UInt16(kVK_Home): "↖",
        UInt16(kVK_End): "↘",
        UInt16(kVK_PageUp): "⇞",
        UInt16(kVK_PageDown): "⇟",
        UInt16(kVK_ANSI_KeypadEnter): "⌤",
        UInt16(kVK_F1): "F1", UInt16(kVK_F2): "F2", UInt16(kVK_F3): "F3",
        UInt16(kVK_F4): "F4", UInt16(kVK_F5): "F5", UInt16(kVK_F6): "F6",
        UInt16(kVK_F7): "F7", UInt16(kVK_F8): "F8", UInt16(kVK_F9): "F9",
        UInt16(kVK_F10): "F10", UInt16(kVK_F11): "F11", UInt16(kVK_F12): "F12",
        UInt16(kVK_F13): "F13", UInt16(kVK_F14): "F14", UInt16(kVK_F15): "F15",
        UInt16(kVK_F16): "F16", UInt16(kVK_F17): "F17", UInt16(kVK_F18): "F18",
        UInt16(kVK_F19): "F19", UInt16(kVK_F20): "F20"
    ]

    /// 字母与数字按当前键盘布局翻译，保证 QWERTY 之外的布局也显示正确。
    static func keyName(for keyCode: UInt16) -> String {
        if let named = namedKeys[keyCode] { return named }
        if let translated = translateUsingCurrentLayout(keyCode) { return translated }
        return "键 \(keyCode)"
    }

    private static func translateUsingCurrentLayout(_ keyCode: UInt16) -> String? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?
            .takeRetainedValue(),
            let layoutPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else {
            return nil
        }

        let layoutData = Unmanaged<CFData>.fromOpaque(layoutPointer).takeUnretainedValue() as Data
        return layoutData.withUnsafeBytes { buffer -> String? in
            guard let header = buffer.baseAddress?
                .assumingMemoryBound(to: UCKeyboardLayout.self)
            else {
                return nil
            }

            var deadKeyState: UInt32 = 0
            var characters = [UniChar](repeating: 0, count: 4)
            var length = 0

            let status = UCKeyTranslate(
                header,
                keyCode,
                UInt16(kUCKeyActionDisplay),
                0, // 不带修饰键，取键帽本身的字符
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                characters.count,
                &length,
                &characters
            )

            guard status == noErr, length > 0 else { return nil }
            return String(utf16CodeUnits: characters, count: length).uppercased()
        }
    }
}
