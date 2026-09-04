import Foundation
import XCTest
@testable import TempoTasks

@MainActor
final class TaskPanelViewModelTests: XCTestCase {
    private final class FakeRepository: TaskRepository {
        var items: [TaskItem] = []
        var shouldFailFetch = false
        var shouldFailWrite = false

        func fetchTasks(on day: LocalDay) throws -> [TaskItem] {
            if shouldFailFetch { throw TestError.fetch }
            return items
                .filter { !$0.isUnscheduled && $0.localDay == day }
                .sorted(by: SwiftDataTaskRepository.sortTasks)
        }

        func fetchBacklog(today: LocalDay) throws -> [TaskItem] {
            if shouldFailFetch { throw TestError.fetch }
            return items
                .filter { !$0.isCompleted && ($0.isUnscheduled || $0.localDay < today) }
                .sorted(by: SwiftDataTaskRepository.sortBacklog)
        }

        func create(title: String, dueDay: LocalDay, isUnscheduled: Bool, now: Date) throws -> TaskItem {
            if shouldFailWrite { throw TestError.write }
            let item = TaskItem(
                title: title,
                dueDay: dueDay,
                createdAt: now,
                isUnscheduled: isUnscheduled
            )
            items.append(item)
            return item
        }

        func fetchCompleted(limit: Int) throws -> [TaskItem] {
            if shouldFailFetch { throw TestError.fetch }
            return items
                .filter(\.isCompleted)
                .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
                .prefix(limit)
                .map { $0 }
        }

        func setCompleted(_ task: TaskItem, completed: Bool, now: Date) throws {
            if shouldFailWrite { throw TestError.write }
            task.isCompleted = completed
            task.completedAt = completed ? now : nil
        }

        func setCompleted(_ tasks: [TaskItem], completed: Bool, now: Date) throws {
            if shouldFailWrite { throw TestError.write }
            for task in tasks {
                task.isCompleted = completed
                task.completedAt = completed ? now : nil
            }
        }

        func schedule(_ task: TaskItem, to day: LocalDay?) throws {
            if shouldFailWrite { throw TestError.write }
            if let day {
                task.isUnscheduled = false
                task.localDay = day
            } else {
                task.isUnscheduled = true
            }
        }

        func delete(_ task: TaskItem) throws -> TaskSnapshot {
            if shouldFailWrite { throw TestError.write }
            let snapshot = task.snapshot
            items.removeAll { $0.id == task.id }
            return snapshot
        }

        func restore(snapshot: TaskSnapshot) throws -> TaskItem {
            if shouldFailWrite { throw TestError.write }
            let item = TaskItem(
                id: snapshot.id,
                title: snapshot.title,
                dueDay: snapshot.dueDay,
                isCompleted: snapshot.isCompleted,
                createdAt: snapshot.createdAt,
                completedAt: snapshot.completedAt
            )
            items.append(item)
            return item
        }
    }

    private enum TestError: Error {
        case fetch
        case write
    }

    private let fixedNow = Date(timeIntervalSince1970: 1_787_070_400)
    private let utc = TimeZone(secondsFromGMT: 0)!

    func testSubmittingValidDraftCreatesTaskAndKeepsSelectedDate() {
        let repository = FakeRepository()
        let model = TaskPanelViewModel(
            repository: repository,
            nowProvider: { self.fixedNow },
            timeZoneProvider: { self.utc }
        )
        let customDay = LocalDay(year: 2026, month: 8, day: 23)
        model.select(.custom(customDay))
        model.draft = "  整理产品复盘  "

        model.submitDraft()

        XCTAssertEqual(repository.items.count, 1)
        XCTAssertEqual(repository.items.first?.title, "整理产品复盘")
        XCTAssertEqual(repository.items.first?.localDay, customDay)
        XCTAssertTrue(model.draft.isEmpty)
    }

    func testOverlongDraftIsPreservedAndNotCreated() {
        let repository = FakeRepository()
        let model = TaskPanelViewModel(repository: repository)
        model.draft = String(repeating: "任", count: 501)

        model.submitDraft()

        XCTAssertTrue(repository.items.isEmpty)
        XCTAssertEqual(model.draft.count, 501)
        XCTAssertEqual(model.inputError, "任务不能超过 500 个字符")
    }

    func testFetchFailureUsesSameDayCacheOnly() {
        let repository = FakeRepository()
        let today = LocalDay.today(now: fixedNow, timeZone: utc)
        repository.items = [TaskItem(title: "缓存任务", dueDay: today)]
        let model = TaskPanelViewModel(
            repository: repository,
            nowProvider: { self.fixedNow },
            timeZoneProvider: { self.utc }
        )
        // 面板默认停在待办；按天缓存要在某一天的视图下验证。
        model.select(.today)
        XCTAssertEqual(model.tasks.map(\.title), ["缓存任务"])

        repository.shouldFailFetch = true
        model.loadTasks()
        XCTAssertEqual(model.tasks.map(\.title), ["缓存任务"])
        XCTAssertTrue(model.isShowingCachedTasks)

        model.select(.tomorrow)
        XCTAssertTrue(model.tasks.isEmpty)
        XCTAssertFalse(model.isShowingCachedTasks)
        XCTAssertEqual(model.loadError, "无法读取任务")
    }

    func testUndoRestoresCompleteSnapshot() {
        let repository = FakeRepository()
        let day = LocalDay.today(now: fixedNow, timeZone: utc)
        let completedAt = fixedNow.addingTimeInterval(100)
        let item = TaskItem(
            title: "已完成任务",
            dueDay: day,
            isCompleted: true,
            createdAt: fixedNow,
            completedAt: completedAt
        )
        repository.items = [item]
        let model = TaskPanelViewModel(
            repository: repository,
            nowProvider: { self.fixedNow },
            timeZoneProvider: { self.utc }
        )

        model.delete(item)
        model.undoDelete()

        XCTAssertEqual(repository.items.first?.id, item.id)
        XCTAssertEqual(repository.items.first?.createdAt, fixedNow)
        XCTAssertEqual(repository.items.first?.completedAt, completedAt)
    }
}
