import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let contextMenu = NSMenu()
    private let hotKeyStatusItem = NSMenuItem(title: "Control + Space 可用", action: nil, keyEquivalent: "")
    private let onToggle: () -> Void
    private let onOpen: () -> Void
    private(set) var hotKeyAvailable = true

    init(onToggle: @escaping () -> Void, onOpen: @escaping () -> Void) {
        self.onToggle = onToggle
        self.onOpen = onOpen
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureButton()
        configureMenu()
    }

    func setHotKeyAvailable(_ available: Bool) {
        hotKeyAvailable = available
        hotKeyStatusItem.title = available
            ? "Control + Space 可用"
            : "Control + Space 不可用"
        hotKeyStatusItem.image = NSImage(
            systemSymbolName: available ? "checkmark.circle" : "exclamationmark.triangle",
            accessibilityDescription: nil
        )
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(
            systemSymbolName: "checkmark.square",
            accessibilityDescription: "TempoTasks"
        )
        button.image?.isTemplate = true
        button.toolTip = "TempoTasks · Control + Space"
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configureMenu() {
        let openItem = NSMenuItem(title: "打开 TempoTasks", action: #selector(openPanel), keyEquivalent: "")
        openItem.target = self
        contextMenu.addItem(openItem)
        hotKeyStatusItem.isEnabled = false
        contextMenu.addItem(hotKeyStatusItem)
        contextMenu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 TempoTasks", action: #selector(quitApplication), keyEquivalent: "q")
        quitItem.target = self
        contextMenu.addItem(quitItem)
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent, let button = statusItem.button else {
            onToggle()
            return
        }
        if event.type == .rightMouseUp {
            NSMenu.popUpContextMenu(contextMenu, with: event, for: button)
        } else {
            onToggle()
        }
    }

    @objc private func openPanel() {
        onOpen()
    }

    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }
}
