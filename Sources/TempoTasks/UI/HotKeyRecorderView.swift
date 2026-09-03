import AppKit
import SwiftUI

/// 快捷键录制控件。
///
/// 录制期间用 local event monitor 吞掉所有按键，否则 Escape 会被面板的
/// `onExitCommand` 抢走直接关窗，Command + 字母也会触发菜单。
struct HotKeyRecorderView: View {
    let combo: HotKeyCombo
    let isConflicting: Bool
    let onChange: (HotKeyCombo) -> Void

    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var showsModifierHint = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: TempoTheme.Space.sm) {
            Button(action: toggleRecording) {
                HStack(spacing: TempoTheme.Space.sm) {
                    keyCapContent
                    Text(isRecording ? "按下新组合" : "唤出 / 隐藏")
                        .font(.system(size: TempoTheme.FontSize.micro))
                        .foregroundStyle(TempoTheme.secondaryText)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(TempoPressableButtonStyle())
            .help(isRecording ? "按下新的快捷键组合，Escape 取消" : "点击修改快捷键")
            .accessibilityLabel(
                isRecording
                    ? "正在录制快捷键，按下新组合，或按 Escape 取消"
                    : "修改唤出快捷键，当前为 \(combo.accessibilityDescription)"
            )

            if showsModifierHint {
                hintText("需要含 Control、Option 或 Command")
            } else if isConflicting {
                hintText("该组合已被占用，点击换一个")
            }
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: TempoTheme.Motion.quick),
            value: isRecording
        )
        .onDisappear(perform: stopRecording)
    }

    private var keyCapContent: some View {
        Text(isRecording ? "…" : combo.displayString)
            .font(.system(size: TempoTheme.FontSize.micro, weight: .semibold, design: .monospaced))
            .foregroundStyle(keyCapForeground)
            .padding(.horizontal, TempoTheme.Space.xs + 1)
            .frame(minWidth: 52, minHeight: TempoTheme.Space.lg)
            .background(isRecording ? TempoTheme.focusBlue.opacity(0.16) : TempoTheme.raised)
            .clipShape(RoundedRectangle(cornerRadius: TempoTheme.Radius.sm, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: TempoTheme.Radius.sm, style: .continuous)
                    .stroke(keyCapBorder, lineWidth: 1)
            }
    }

    private var keyCapForeground: Color {
        if isRecording { return TempoTheme.focusBlue }
        return isConflicting ? TempoTheme.completionCoral : TempoTheme.secondaryText
    }

    private var keyCapBorder: Color {
        if isRecording { return TempoTheme.focusBlue.opacity(0.6) }
        return isConflicting ? TempoTheme.completionCoral.opacity(0.5) : TempoTheme.hairline
    }

    private func hintText(_ message: String) -> some View {
        Text(message)
            .font(.system(size: TempoTheme.FontSize.micro))
            .foregroundStyle(TempoTheme.completionCoral)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - 录制

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        guard monitor == nil else { return }
        isRecording = true
        showsModifierHint = false

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            guard event.type == .keyDown else { return nil }
            handleKeyDown(event)
            return nil
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        let bareModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // 不带修饰键的 Escape 表示放弃录制，保持原有组合。
        if event.keyCode == 53, bareModifiers.isEmpty {
            stopRecording()
            return
        }

        guard let newCombo = HotKeyCombo(event: event) else {
            showsModifierHint = true
            return
        }

        stopRecording()
        onChange(newCombo)
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        isRecording = false
        showsModifierHint = false
    }
}
