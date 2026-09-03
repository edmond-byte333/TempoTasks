import Foundation
import Observation

@MainActor
@Observable
final class TaskPanelViewModel {
    enum DateSelection: Equatable {
        case today
        case tomorrow
        case custom(LocalDay)
    }

    private let repository: TaskRepository
    private let nowProvider: () -> Date
    private let timeZoneProvider: () -> TimeZone
    private var taskCache: [LocalDay: [TaskItem]] = [:]
    private var undoExpiryTask: Task<Void, Never>?

    var selection: DateSelection = .today
    var today: LocalDay
    var tomorrow: LocalDay
    var lastCustomDay: LocalDay?
    var draft = ""
    var tasks: [TaskItem] = []
    var inputError: String?
    var loadError: String?
    var isShowingCachedTasks = false
    var isDatePickerPresented = false
    var undoSnapshot: TaskSnapshot?
    var undoRetryRequired = false
    var hotKeyAvailable = true
    var hotKeyCombo: HotKeyCombo = .default

    /// 由 AppDelegate 接管：重新注册热键、写入偏好设置、回填 `hotKeyAvailable`。
    var onHotKeyChange: ((HotKeyCombo) -> Void)?

    init(
        repository: TaskRepository,
        nowProvider: @escaping () -> Date = Date.init,
        timeZoneProvider: @escaping () -> TimeZone = { .autoupdatingCurrent }
    ) {
        self.repository = repository
        self.nowProvider = nowProvider
        self.timeZoneProvider = timeZoneProvider
        let now = nowProvider()
        let timeZone = timeZoneProvider()
        self.today = LocalDay.today(now: now, timeZone: timeZone)
        self.tomorrow = LocalDay.tomorrow(now: now, timeZone: timeZone)
        loadTasks()
    }

    var selectedDay: LocalDay {
        switch selection {
        case .today: today
        case .tomorrow: tomorrow
        case .custom(let day): day
        }
    }

    var selectedDateLabel: String {
        switch selection {
        case .today: "今天"
        case .tomorrow: "明天"
        case .custom(let day):
            day.formatted(locale: LocalDay.displayLocale, timeZone: timeZoneProvider())
        }
    }

    var emptyStateMessage: String {
        switch selection {
        case .today: "今天还没有任务"
        case .tomorrow: "明天还没有任务"
        case .custom(let day):
            "\(day.formatted(locale: LocalDay.displayLocale, timeZone: timeZoneProvider()))还没有任务"
        }
    }

    var completedCount: Int { tasks.lazy.filter(\.isCompleted).count }

    /// 与当前组合相同就不重复注册，避免录到同一个键时白白解绑一次。
    func updateHotKey(_ combo: HotKeyCombo) {
        guard combo != hotKeyCombo else { return }
        hotKeyCombo = combo
        onHotKeyChange?(combo)
    }

    func prepareForPresentation() {
        refreshCalendarContext()
        loadTasks()
    }

    func refreshCalendarContext() {
        let now = nowProvider()
        let timeZone = timeZoneProvider()
        today = LocalDay.today(now: now, timeZone: timeZone)
        tomorrow = LocalDay.tomorrow(now: now, timeZone: timeZone)
    }

    func select(_ newSelection: DateSelection) {
        selection = newSelection
        if case .custom(let day) = newSelection {
            lastCustomDay = day
        }
        loadTasks()
    }

    func chooseCustomDate(_ date: Date) {
        let day = LocalDay(date: date, timeZone: timeZoneProvider())
        if day == today {
            select(.today)
        } else if day == tomorrow {
            select(.tomorrow)
        } else {
            select(.custom(day))
        }
        isDatePickerPresented = false
    }

    func submitDraft() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        guard title.count <= 500 else {
            inputError = "任务不能超过 500 个字符"
            return
        }

        do {
            _ = try repository.create(title: title, dueDay: selectedDay, now: nowProvider())
            draft = ""
            inputError = nil
            loadTasks()
        } catch {
            inputError = "任务未保存，请重试"
        }
    }

    func draftDidChange() {
        if draft.count <= 500 {
            inputError = nil
        }
    }

    func toggleCompletion(_ task: TaskItem) {
        do {
            try repository.setCompleted(task, completed: !task.isCompleted, now: nowProvider())
            loadTasks()
        } catch {
            loadError = "完成状态未保存，请重试"
        }
    }

    func delete(_ task: TaskItem) {
        do {
            let snapshot = try repository.delete(task)
            taskCache[selectedDay] = tasks.filter { $0.id != task.id }
            tasks = taskCache[selectedDay] ?? []
            beginUndoWindow(for: snapshot)
        } catch {
            loadError = "任务未删除，请重试"
        }
    }

    func undoDelete() {
        guard let snapshot = undoSnapshot else { return }
        undoExpiryTask?.cancel()
        do {
            _ = try repository.restore(snapshot: snapshot)
            undoSnapshot = nil
            undoRetryRequired = false
            loadTasks()
        } catch {
            undoRetryRequired = true
            loadError = "任务未恢复，请重试"
        }
    }

    func retryLoad() {
        if undoRetryRequired, undoSnapshot != nil {
            undoDelete()
        } else {
            loadTasks()
        }
    }

    func loadTasks() {
        let day = selectedDay
        do {
            let fetched = try repository.fetchTasks(on: day)
            taskCache[day] = fetched
            tasks = fetched
            loadError = nil
            isShowingCachedTasks = false
        } catch {
            if let cached = taskCache[day] {
                tasks = cached
                loadError = "任务可能不是最新"
                isShowingCachedTasks = true
            } else {
                tasks = []
                loadError = "无法读取任务"
                isShowingCachedTasks = false
            }
        }
    }

    private func beginUndoWindow(for snapshot: TaskSnapshot) {
        undoExpiryTask?.cancel()
        undoSnapshot = snapshot
        undoRetryRequired = false
        undoExpiryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.undoSnapshot = nil
        }
    }
}
