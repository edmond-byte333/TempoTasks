import Foundation
import Testing
@testable import TempoTasks

struct LocalDayTests {
    @Test func extractsCivilDayInRequestedTimeZone() {
        let timestamp = Date(timeIntervalSince1970: 1_725_187_400)
        let shanghai = TimeZone(identifier: "Asia/Shanghai")!
        let losAngeles = TimeZone(identifier: "America/Los_Angeles")!

        #expect(LocalDay(date: timestamp, timeZone: shanghai) == LocalDay(year: 2024, month: 9, day: 1))
        #expect(LocalDay(date: timestamp, timeZone: losAngeles) == LocalDay(year: 2024, month: 9, day: 1))
    }

    @Test func storedCivilDayDoesNotChangeWithTimeZone() {
        let day = LocalDay(year: 2026, month: 8, day: 19)
        #expect(day.year == 2026)
        #expect(day.month == 8)
        #expect(day.day == 19)
        #expect(day.date(timeZone: TimeZone(identifier: "Asia/Shanghai")!) != nil)
        #expect(day.date(timeZone: TimeZone(identifier: "America/New_York")!) != nil)
    }

    @Test func addingDayCrossesMonth() {
        let utc = TimeZone(secondsFromGMT: 0)!
        let result = LocalDay(year: 2026, month: 8, day: 31).addingDays(1, timeZone: utc)
        #expect(result == LocalDay(year: 2026, month: 9, day: 1))
    }
}
