import Foundation
import SwiftData

@Model
final class TaskItem {
    var id: UUID
    var title: String
    var dueYear: Int
    var dueMonth: Int
    var dueDay: Int
    var isCompleted: Bool
    var createdAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        dueDay: LocalDay,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.dueYear = dueDay.year
        self.dueMonth = dueDay.month
        self.dueDay = dueDay.day
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.completedAt = completedAt
    }

    var localDay: LocalDay {
        get { LocalDay(year: dueYear, month: dueMonth, day: dueDay) }
        set {
            dueYear = newValue.year
            dueMonth = newValue.month
            dueDay = newValue.day
        }
    }

    var snapshot: TaskSnapshot {
        TaskSnapshot(
            id: id,
            title: title,
            dueDay: localDay,
            isCompleted: isCompleted,
            createdAt: createdAt,
            completedAt: completedAt
        )
    }
}

struct TaskSnapshot: Equatable, Sendable {
    let id: UUID
    let title: String
    let dueDay: LocalDay
    let isCompleted: Bool
    let createdAt: Date
    let completedAt: Date?
}
