import Foundation
import SwiftData

@MainActor
protocol TaskRepository: AnyObject {
    func fetchTasks(on day: LocalDay) throws -> [TaskItem]

    @discardableResult
    func create(title: String, dueDay: LocalDay, now: Date) throws -> TaskItem

    func setCompleted(_ task: TaskItem, completed: Bool, now: Date) throws
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
        let predicate = #Predicate<TaskItem> { item in
            item.dueYear == year && item.dueMonth == month && item.dueDay == numericDay
        }
        let items = try context.fetch(FetchDescriptor<TaskItem>(predicate: predicate))
        return items.sorted(by: Self.sortTasks)
    }

    @discardableResult
    func create(title: String, dueDay: LocalDay, now: Date = Date()) throws -> TaskItem {
        let item = TaskItem(title: title, dueDay: dueDay, createdAt: now)
        context.insert(item)
        do {
            try context.save()
            return item
        } catch {
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
            completedAt: snapshot.completedAt
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
