import AppKit
import SwiftData

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var container: ModelContainer?
    private var viewModel: TaskPanelViewModel?
    private var panelController: PanelController?
    private var statusBarController: StatusBarController?
    private var hotKeyRegistrar: GlobalHotKeyRegistrar?
    private var notificationTokens: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureApplication()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyRegistrar?.unregister()
        notificationTokens.forEach(NotificationCenter.default.removeObserver)
    }

    private func configureApplication() {
        do {
            let configuration = ModelConfiguration(
                isStoredInMemoryOnly: CommandLine.arguments.contains("--in-memory")
            )
            let container = try ModelContainer(
                for: TaskItem.self,
                configurations: configuration
            )
            self.container = container
            let repository = SwiftDataTaskRepository(context: container.mainContext)
            let viewModel = TaskPanelViewModel(repository: repository)
            self.viewModel = viewModel

            let panelController = PanelController(viewModel: viewModel)
            self.panelController = panelController

            let statusBarController = StatusBarController(
                onToggle: { panelController.toggle() },
                onOpen: { panelController.show() }
            )
            self.statusBarController = statusBarController

            let hotKeyRegistrar = GlobalHotKeyRegistrar()
            hotKeyRegistrar.onPressed = {
                Task { @MainActor in panelController.toggle() }
            }
            let hotKeyAvailable = hotKeyRegistrar.register()
            self.hotKeyRegistrar = hotKeyRegistrar
            viewModel.hotKeyAvailable = hotKeyAvailable
            statusBarController.setHotKeyAvailable(hotKeyAvailable)

            observeCalendarChanges()

            if CommandLine.arguments.contains("--show-panel") {
                DispatchQueue.main.async {
                    panelController.show()
                }
            }
        } catch {
            presentStorageFailure(error)
        }
    }

    private func observeCalendarChanges() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            .NSCalendarDayChanged,
            .NSSystemTimeZoneDidChange
        ]
        notificationTokens = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.viewModel?.refreshCalendarContext()
                    self?.viewModel?.loadTasks()
                }
            }
        }
    }

    private func presentStorageFailure(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "无法打开本地任务数据"
        alert.informativeText = "TempoTasks 无法访问本地存储。请退出后重新打开应用。\n\n\(error.localizedDescription)"
        alert.addButton(withTitle: "退出应用")
        alert.runModal()
        NSApp.terminate(nil)
    }
}
