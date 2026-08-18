import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private let panel: FloatingPanel
    private let viewModel: TaskPanelViewModel
    private var positionMemory = PanelPositionMemory()
    private var screenParametersChangedWhileHidden = false
    private var screenParametersObserver: NSObjectProtocol?

    init(viewModel: TaskPanelViewModel) {
        self.viewModel = viewModel
        self.panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.delegate = self
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.contentView = NSHostingView(
            rootView: TaskPanelView(
                viewModel: viewModel,
                onClose: { [weak self] in self?.hide() },
                onDragBegan: { [weak self] in self?.beginUserDrag() },
                onDragEnded: { [weak self] originalFrame, currentFrame in
                    self?.endUserDrag(originalFrame: originalFrame, currentFrame: currentFrame)
                }
            )
        )

        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.screenParametersDidChange()
            }
        }
    }

    deinit {
        if let screenParametersObserver {
            NotificationCenter.default.removeObserver(screenParametersObserver)
        }
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    func show() {
        viewModel.prepareForPresentation()
        preparePositionForPresentation()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .tempoFocusInput, object: nil)
        }
    }

    func hide() {
        panel.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        // SwiftUI popovers (such as the graphical date picker) use their own
        // key window. Keep the panel visible while TempoTasks is still active;
        // `hidesOnDeactivate` handles clicks into another application.
        DispatchQueue.main.async { [weak self] in
            guard !NSApp.isActive else { return }
            self?.hide()
        }
    }

    private func beginUserDrag() {
        positionMemory.beginDrag(at: panel.frame)
    }

    private func endUserDrag(originalFrame: NSRect, currentFrame: NSRect) {
        let visibleFrames = NSScreen.screens.map(\.visibleFrame)
        guard let storedFrame = positionMemory.endDrag(
            originalFrame: originalFrame,
            currentFrame: currentFrame,
            visibleFrames: visibleFrames
        ) else {
            return
        }
        panel.setFrame(storedFrame, display: true)
    }

    private func preparePositionForPresentation() {
        if !screenParametersChangedWhileHidden,
           let storedFrame = positionMemory.storedFrame {
            panel.setFrame(storedFrame, display: false)
            return
        }

        let visibleFrames = NSScreen.screens.map(\.visibleFrame)
        if let storedFrame = positionMemory.validStoredFrame(in: visibleFrames) {
            panel.setFrame(storedFrame, display: false)
        } else {
            positionOnCurrentScreen()
        }
        screenParametersChangedWhileHidden = false
    }

    private func screenParametersDidChange() {
        screenParametersChangedWhileHidden = true
        if panel.isVisible {
            preparePositionForPresentation()
        }
    }

    private func positionOnCurrentScreen() {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return }

        let frame = PanelPositionMemory.defaultFrame(
            panelSize: panel.frame.size,
            in: screen.visibleFrame
        )
        panel.setFrame(frame, display: false)
    }
}
