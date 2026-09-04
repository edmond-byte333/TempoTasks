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

    /// 未安排到具体某天的任务，属于「待办」。
    ///
    /// 用新增的带默认值属性而不是把 `dueYear/dueMonth/dueDay` 改成可选，
    /// 是为了让已有数据走 SwiftData 的轻量迁移：老任务自动填 false，行为不变。
    /// 未安排任务的三个日期字段仍存创建当天，只作为排序与回退用，不参与按日查询。
    var isUnscheduled: Bool = false

    init(
        id: UUID = UUID(),
        title: String,
        dueDay: LocalDay,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        isUnscheduled: Bool = false
    ) {
        self.id = id
        self.title = title
        self.dueYear = dueDay.year
        self.dueMonth = dueDay.month
        self.dueDay = dueDay.day
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.isUnscheduled = isUnscheduled
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
            completedAt: completedAt,
            isUnscheduled: isUnscheduled
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
    var isUnscheduled: Bool = false
}
