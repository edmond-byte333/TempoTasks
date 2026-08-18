import Foundation
import SwiftData
import XCTest
@testable import TempoTasks

final class TaskRepositoryTests: XCTestCase {
    @MainActor
    private func makeRepository() throws -> (ModelContainer, SwiftDataTaskRepository) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TaskItem.self, configurations: configuration)
        return (container, SwiftDataTaskRepository(context: container.mainContext))
    }

    @MainActor
    func testCreateFetchCompleteRestoreAndDelete() throws {
        let (container, repository) = try makeRepository()
        _ = container
        let day = LocalDay(year: 2026, month: 8, day: 19)
        let createdAt = Date(timeIntervalSince1970: 100)
        let item = try repository.create(title: "写产品复盘", dueDay: day, now: createdAt)

        XCTAssertEqual(try repository.fetchTasks(on: day).map(\.title), ["写产品复盘"])

        try repository.setCompleted(item, completed: true, now: Date(timeIntervalSince1970: 200))
        XCTAssertTrue(item.isCompleted)
        XCTAssertEqual(item.completedAt, Date(timeIntervalSince1970: 200))

        let originalID = item.id
        let snapshot = try repository.delete(item)
        XCTAssertTrue(try repository.fetchTasks(on: day).isEmpty)

        let restored = try repository.restore(snapshot: snapshot)
        XCTAssertEqual(restored.id, originalID)
        XCTAssertEqual(restored.createdAt, createdAt)
        XCTAssertEqual(restored.completedAt, Date(timeIntervalSince1970: 200))
    }

    @MainActor
    func testUnfinishedTasksPrecedeCompletedTasksWithStableOrdering() throws {
        let (container, repository) = try makeRepository()
        _ = container
        let day = LocalDay(year: 2026, month: 8, day: 19)
        let first = try repository.create(title: "第一项", dueDay: day, now: Date(timeIntervalSince1970: 10))
        let second = try repository.create(title: "第二项", dueDay: day, now: Date(timeIntervalSince1970: 20))
        try repository.setCompleted(first, completed: true, now: Date(timeIntervalSince1970: 30))

        let tasks = try repository.fetchTasks(on: day)
        XCTAssertEqual(tasks.map(\.id), [second.id, first.id])
    }

    @MainActor
    func testTaskPersistsAfterContainerIsReopened() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TempoTasksTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appendingPathComponent("TempoTasks.store")
        let day = LocalDay(year: 2026, month: 8, day: 21)

        do {
            let configuration = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(for: TaskItem.self, configurations: configuration)
            let repository = SwiftDataTaskRepository(context: container.mainContext)
            _ = try repository.create(title: "跨重启保留", dueDay: day, now: Date(timeIntervalSince1970: 300))
        }

        do {
            let configuration = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(for: TaskItem.self, configurations: configuration)
            let repository = SwiftDataTaskRepository(context: container.mainContext)
            let tasks = try repository.fetchTasks(on: day)
            XCTAssertEqual(tasks.map(\.title), ["跨重启保留"])
        }
    }
}
