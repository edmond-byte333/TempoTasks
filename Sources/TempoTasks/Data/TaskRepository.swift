import Foundation
import SwiftData

@MainActor
protocol TaskRepository: AnyObject {
    func fetchTasks(on day: LocalDay) throws -> [TaskItem]

    /// 「待办」：还没安排到某天的，加上安排了却已经过期没做完的。
    /// 两类都是欠着的事，放同一个出口，用户只需要看一个地方。
    func fetchBacklog(today: LocalDay) throws -> [TaskItem]

    /// 已完成记录，按完成时间倒序。
    func fetchCompleted(limit: Int) throws -> [TaskItem]

    @discardableResult
    func create(title: String, dueDay: LocalDay, isUnscheduled: Bool, now: Date) throws -> TaskItem

    func setCompleted(_ task: TaskItem, completed: Bool, now: Date) throws

    /// 批量改完成状态，一次落库；失败时整批回滚。
    func setCompleted(_ tasks: [TaskItem], completed: Bool, now: Date) throws

    /// 传 nil 表示移回待办。没有这个出口，待办池只进不出。
    func schedule(_ task: TaskItem, to day: LocalDay?) throws

    func delete(_ task: TaskItem) throws -> TaskSnapshot

    @discardableResult
    func restore(snapshot: TaskSnapshot) throws -> TaskItem
}

@MainActor
final class SwiftDataTaskRepository: TaskRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        self.context.autosaveEnabled = false
    }

    func fetchTasks(on day: LocalDay) throws -> [TaskItem] {
        let year = day.year
        let month = day.month
        let numericDay = day.day
        // 未安排的任务日期字段存的是创建当天，必须排除，否则它们会混进那天的列表。
        let predicate = #Predicate<TaskItem> { item in
            !item.isUnscheduled
                && item.dueYear == year && item.dueMonth == month && item.dueDay == numericDay
        }
        let items = try context.fetch(FetchDescriptor<TaskItem>(predicate: predicate))
        return items.sorted(by: Self.sortTasks)
    }

    func fetchBacklog(today: LocalDay) throws -> [TaskItem] {
        // 逾期判断要比较 year/month/day 三段，写成 #Predicate 既难读又易错。
        // 个人工具的未完成任务量级很小，先按 isCompleted 收窄再在内存里筛。
        let predicate = #Predicate<TaskItem> { !$0.isCompleted }
        let items = try context.fetch(FetchDescriptor<TaskItem>(predicate: predicate))
        return items
            .filter { $0.isUnscheduled || $0.localDay < today }
            .sorted(by: Self.sortBacklog)
    }

    /// 排序和截断都交给数据库做，避免把整张表读进内存再排。
    func fetchCompleted(limit: Int = 500) throws -> [TaskItem] {
        let predicate = #Predicate<TaskItem> { $0.isCompleted }
        var descriptor = FetchDescriptor<TaskItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    @discardableResult
    func create(
        title: String,
        dueDay: LocalDay,
        isUnscheduled: Bool = false,
        now: Date = Date()
    ) throws -> TaskItem {
        let item = TaskItem(
            title: title,
            dueDay: dueDay,
            createdAt: now,
            isUnscheduled: isUnscheduled
        )
        context.insert(item)
        do {
            try context.save()
            return item
        } catch {
            context.rollback()
            throw error
        }
    }

    func setCompleted(_ tasks: [TaskItem], completed: Bool, now: Date = Date()) throws {
        let previous = tasks.map { ($0, $0.isCompleted, $0.completedAt) }
        for task in tasks {
            task.isCompleted = completed
            task.completedAt = completed ? now : nil
        }
        do {
            try context.save()
        } catch {
            for (task, wasCompleted, completedAt) in previous {
                task.isCompleted = wasCompleted
                task.completedAt = completedAt
            }
            context.rollback()
            throw error
        }
    }

    func schedule(_ task: TaskItem, to day: LocalDay?) throws {
        let previousUnscheduled = task.isUnscheduled
        let previousDay = task.localDay
        if let day {
            task.isUnscheduled = false
            task.localDay = day
        } else {
            task.isUnscheduled = true
        }
        do {
            try context.save()
        } catch {
            task.isUnscheduled = previousUnscheduled
            task.localDay = previousDay
            context.rollback()
            throw error
        }
    }

    func setCompleted(_ task: TaskItem, completed: Bool, now: Date = Date()) throws {
        let previousCompleted = task.isCompleted
        let previousCompletedAt = task.completedAt
        task.isCompleted = completed
        task.completedAt = completed ? now : nil
        do {
            try context.save()
        } catch {
            task.isCompleted = previousCompleted
            task.completedAt = previousCompletedAt
            context.rollback()
            throw error
        }
    }

    func delete(_ task: TaskItem) throws -> TaskSnapshot {
        let snapshot = task.snapshot
        context.delete(task)
        do {
            try context.save()
            return snapshot
        } catch {
            context.rollback()
            throw error
        }
    }

    @discardableResult
    func restore(snapshot: TaskSnapshot) throws -> TaskItem {
        let item = TaskItem(
            id: snapshot.id,
            title: snapshot.title,
            dueDay: snapshot.dueDay,
            isCompleted: snapshot.isCompleted,
            createdAt: snapshot.createdAt,
            completedAt: snapshot.completedAt,
            isUnscheduled: snapshot.isUnscheduled
        )
        context.insert(item)
        do {
            try context.save()
            return item
        } catch {
            context.rollback()
            throw error
        }
    }

    /// 未安排的排在逾期前面：待办视图的主要用途是快速记录，
    /// 新记下的东西落在这一组，放在最前面才能在回车后立刻看到。
    /// 逾期之间越久的越靠前。
    static func sortBacklog(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        if lhs.isUnscheduled != rhs.isUnscheduled {
            return lhs.isUnscheduled
        }
        // 待处理之间按日期从近到远：刚过期的往往还救得回来，
        // 欠很久的多半已经不重要了。紧迫程度另由文字亮度表达。
        if !lhs.isUnscheduled, lhs.localDay != rhs.localDay {
            return lhs.localDay > rhs.localDay
        }
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    static func sortTasks(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        if lhs.isCompleted != rhs.isCompleted {
            return !lhs.isCompleted
        }
        if lhs.isCompleted {
            let left = lhs.completedAt ?? .distantPast
            let right = rhs.completedAt ?? .distantPast
            if left != right { return left > right }
        } else if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
