import Foundation
import Observation

@MainActor
@Observable
final class TaskPanelViewModel {
    enum DateSelection: Equatable {
        /// 未安排 + 已逾期，面板默认停在这里。
        case backlog
        case today
        case tomorrow
        case custom(LocalDay)
        /// 已完成记录，只读的归档视图。
        case completed
    }

    private let repository: TaskRepository
    private let nowProvider: () -> Date
    private let timeZoneProvider: () -> TimeZone
    private var taskCache: [LocalDay: [TaskItem]] = [:]
    private var backlogCache: [TaskItem]?
    private var undoExpiryTask: Task<Void, Never>?
    private var bulkUndoExpiryTask: Task<Void, Never>?

    var selection: DateSelection = .backlog
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
    /// 刚被批量完成的任务，撤销窗口内保留。
    var bulkCompleted: [TaskItem]?
    var hotKeyAvailable = true
    var hotKeyCombo: HotKeyCombo = .default
    /// 左栏「待办」徽章上的数字。
    var backlogCount = 0

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

    var isViewingBacklog: Bool { selection == .backlog }
    var isViewingCompleted: Bool { selection == .completed }

    /// 已完成是只读归档，不接受新建。
    var acceptsNewTasks: Bool { !isViewingCompleted }

    /// 待办和已完成都没有对应的某一天；新建走未安排分支，这里的值只作兜底。
    var selectedDay: LocalDay {
        switch selection {
        case .backlog, .completed, .today: today
        case .tomorrow: tomorrow
        case .custom(let day): day
        }
    }

    var selectedDateLabel: String {
        switch selection {
        case .backlog: "待办"
        case .completed: "已完成"
        case .today: "今天"
        case .tomorrow: "明天"
        case .custom(let day):
            day.formatted(locale: LocalDay.displayLocale, timeZone: timeZoneProvider())
        }
    }

    var emptyStateMessage: String {
        switch selection {
        case .backlog: "没有欠着的事"
        case .completed: "还没有完成的任务"
        case .today: "今天还没有任务"
        case .tomorrow: "明天还没有任务"
        case .custom(let day):
            "\(day.formatted(locale: LocalDay.displayLocale, timeZone: timeZoneProvider()))还没有任务"
        }
    }

    var completedCount: Int { tasks.lazy.filter(\.isCompleted).count }

    /// 待办的构成，用于头部说明「欠了什么」。
    var overdueCount: Int { tasks.lazy.filter { !$0.isUnscheduled }.count }
    var unscheduledCount: Int { tasks.lazy.filter(\.isUnscheduled).count }

    /// 顺序跟列表里的分组保持一致：未安排在前，逾期在后。
    /// 空时返回空串，空状态本身已经说了「没有欠着的事」，副标题不必再说一遍。
    var backlogSummary: String {
        var parts: [String] = []
        if unscheduledCount > 0 { parts.append("\(unscheduledCount) 件未安排") }
        if overdueCount > 0 { parts.append("\(overdueCount) 件逾期") }
        return parts.joined(separator: " · ")
    }

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
            _ = try repository.create(
                title: title,
                dueDay: selectedDay,
                isUnscheduled: isViewingBacklog,
                now: nowProvider()
            )
            draft = ""
            inputError = nil
            loadTasks()
        } catch {
            inputError = "任务未保存，请重试"
        }
    }

    /// 整组标记完成。数据没有被删除，加上 5 秒撤销窗口和「已完成」视图两层安全网。
    func completeAll(_ batch: [TaskItem]) {
        guard !batch.isEmpty else { return }
        do {
            try repository.setCompleted(batch, completed: true, now: nowProvider())
            beginBulkUndoWindow(for: batch)
            loadTasks()
        } catch {
            loadError = "批量完成失败，请重试"
        }
    }

    func undoBulkComplete() {
        guard let batch = bulkCompleted else { return }
        bulkUndoExpiryTask?.cancel()
        do {
            try repository.setCompleted(batch, completed: false, now: nowProvider())
            bulkCompleted = nil
            loadTasks()
        } catch {
            loadError = "撤销失败，请重试"
        }
    }

    private func beginBulkUndoWindow(for batch: [TaskItem]) {
        bulkUndoExpiryTask?.cancel()
        bulkCompleted = batch
        bulkUndoExpiryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.bulkCompleted = nil
        }
    }

    /// 传 nil 表示移回待办。
    func schedule(_ task: TaskItem, to day: LocalDay?) {
        do {
            try repository.schedule(task, to: day)
            loadTasks()
        } catch {
            loadError = "日期未更新，请重试"
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
            tasks = tasks.filter { $0.id != task.id }
            if isViewingBacklog {
                backlogCache = tasks
                backlogCount = tasks.count
            } else {
                taskCache[selectedDay] = tasks
            }
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
        switch selection {
        case .backlog: loadBacklog()
        case .completed: loadCompleted()
        default: loadDay(selectedDay)
        }
        refreshBacklogCount()
    }

    private func loadCompleted() {
        do {
            tasks = try repository.fetchCompleted(limit: 500)
            loadError = nil
            isShowingCachedTasks = false
        } catch {
            tasks = []
            loadError = "无法读取已完成记录"
            isShowingCachedTasks = false
        }
    }

    private func loadDay(_ day: LocalDay) {
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

    private func loadBacklog() {
        do {
            let fetched = try repository.fetchBacklog(today: today)
            backlogCache = fetched
            tasks = fetched
            loadError = nil
            isShowingCachedTasks = false
        } catch {
            if let backlogCache {
                tasks = backlogCache
                loadError = "任务可能不是最新"
                isShowingCachedTasks = true
            } else {
                tasks = []
                loadError = "无法读取任务"
                isShowingCachedTasks = false
            }
        }
    }

    /// 徽章在任何视图下都要显示，所以单独刷新，不依赖当前是不是待办视图。
    private func refreshBacklogCount() {
        backlogCount = (try? repository.fetchBacklog(today: today).count) ?? backlogCount
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
