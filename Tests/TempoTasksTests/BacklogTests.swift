import Foundation
import SwiftData
import XCTest
@testable import TempoTasks

final class BacklogTests: XCTestCase {
    @MainActor
    private func makeRepository() throws -> (ModelContainer, SwiftDataTaskRepository) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TaskItem.self, configurations: configuration)
        return (container, SwiftDataTaskRepository(context: container.mainContext))
    }

    private let now = Date(timeIntervalSince1970: 1_787_070_400)
    private let today = LocalDay(year: 2026, month: 9, day: 4)

    @MainActor
    func testBacklogHoldsUnscheduledAndOverdue() throws {
        let (container, repository) = try makeRepository()
        _ = container

        try repository.create(title: "未安排", dueDay: today, isUnscheduled: true, now: now)
        try repository.create(title: "逾期", dueDay: today.addingDays(-2), now: now)
        try repository.create(title: "今天", dueDay: today, now: now)
        try repository.create(title: "明天", dueDay: today.addingDays(1), now: now)

        let backlog = try repository.fetchBacklog(today: today)
        XCTAssertEqual(Set(backlog.map(\.title)), ["未安排", "逾期"])
    }

    @MainActor
    func testCompletedTasksNeverAppearInBacklog() throws {
        let (container, repository) = try makeRepository()
        _ = container

        let overdue = try repository.create(title: "逾期已完成", dueDay: today.addingDays(-5), now: now)
        let unscheduled = try repository.create(title: "未安排已完成", dueDay: today, isUnscheduled: true, now: now)
        try repository.setCompleted(overdue, completed: true, now: now)
        try repository.setCompleted(unscheduled, completed: true, now: now)

        XCTAssertTrue(try repository.fetchBacklog(today: today).isEmpty)
    }

    /// 未安排任务的日期字段存的是创建当天，不能因此混进那天的列表。
    @MainActor
    func testUnscheduledTasksAreExcludedFromDayQueries() throws {
        let (container, repository) = try makeRepository()
        _ = container

        try repository.create(title: "未安排", dueDay: today, isUnscheduled: true, now: now)
        try repository.create(title: "今天", dueDay: today, now: now)

        let dayTasks = try repository.fetchTasks(on: today)
        XCTAssertEqual(dayTasks.map(\.title), ["今天"])
    }

    /// 未安排在前；待处理之间按日期从近到远。
    @MainActor
    func testUnscheduledSortsBeforeOverdueAndNearestOverdueFirst() throws {
        let (container, repository) = try makeRepository()
        _ = container

        try repository.create(title: "欠 9 天", dueDay: today.addingDays(-9), now: now)
        try repository.create(title: "未安排", dueDay: today, isUnscheduled: true, now: now)
        try repository.create(title: "欠 1 天", dueDay: today.addingDays(-1), now: now)

        let backlog = try repository.fetchBacklog(today: today)
        XCTAssertEqual(backlog.map(\.title), ["未安排", "欠 1 天", "欠 9 天"])
    }

    @MainActor
    func testCompletedArchiveIsNewestFirstAndLimited() throws {
        let (container, repository) = try makeRepository()
        _ = container

        let older = try repository.create(title: "先完成的", dueDay: today, now: now)
        let newer = try repository.create(title: "后完成的", dueDay: today, now: now)
        try repository.create(title: "没完成的", dueDay: today, now: now)
        try repository.setCompleted(older, completed: true, now: now)
        try repository.setCompleted(newer, completed: true, now: now.addingTimeInterval(60))

        XCTAssertEqual(
            try repository.fetchCompleted(limit: 500).map(\.title),
            ["后完成的", "先完成的"]
        )
        XCTAssertEqual(try repository.fetchCompleted(limit: 1).map(\.title), ["后完成的"])
    }

    @MainActor
    func testBulkCompleteAndRevert() throws {
        let (container, repository) = try makeRepository()
        _ = container

        let first = try repository.create(title: "一", dueDay: today.addingDays(-1), now: now)
        let second = try repository.create(title: "二", dueDay: today.addingDays(-2), now: now)

        try repository.setCompleted([first, second], completed: true, now: now)
        XCTAssertTrue(try repository.fetchBacklog(today: today).isEmpty)
        XCTAssertEqual(try repository.fetchCompleted(limit: 500).count, 2)

        try repository.setCompleted([first, second], completed: false, now: now)
        XCTAssertEqual(try repository.fetchBacklog(today: today).count, 2)
        XCTAssertTrue(try repository.fetchCompleted(limit: 500).isEmpty)
    }

    @MainActor
    func testSchedulingMovesTaskOutOfBacklogAndBack() throws {
        let (container, repository) = try makeRepository()
        _ = container

        let task = try repository.create(title: "先记下来", dueDay: today, isUnscheduled: true, now: now)
        XCTAssertEqual(try repository.fetchBacklog(today: today).count, 1)

        try repository.schedule(task, to: today)
        XCTAssertTrue(try repository.fetchBacklog(today: today).isEmpty)
        XCTAssertEqual(try repository.fetchTasks(on: today).map(\.title), ["先记下来"])

        try repository.schedule(task, to: nil)
        XCTAssertEqual(try repository.fetchBacklog(today: today).map(\.title), ["先记下来"])
        XCTAssertTrue(try repository.fetchTasks(on: today).isEmpty)
    }

    /// 撤销删除必须把未安排这个属性一起带回来，否则任务会掉进创建当天。
    @MainActor
    func testRestorePreservesUnscheduledFlag() throws {
        let (container, repository) = try makeRepository()
        _ = container

        let task = try repository.create(title: "未安排", dueDay: today, isUnscheduled: true, now: now)
        let snapshot = try repository.delete(task)
        _ = try repository.restore(snapshot: snapshot)

        XCTAssertEqual(try repository.fetchBacklog(today: today).map(\.title), ["未安排"])
        XCTAssertTrue(try repository.fetchTasks(on: today).isEmpty)
    }

    func testDaysBeforeCountsCalendarDays() {
        XCTAssertEqual(today.addingDays(-3).daysBefore(today), 3)
        XCTAssertEqual(today.daysBefore(today), 0)
        XCTAssertEqual(today.addingDays(2).daysBefore(today), -2)
    }
}
