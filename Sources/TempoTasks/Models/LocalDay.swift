import Foundation

struct LocalDay: Hashable, Codable, Sendable, Comparable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(date: Date, timeZone: TimeZone = .autoupdatingCurrent) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(
            year: components.year ?? 1970,
            month: components.month ?? 1,
            day: components.day ?? 1
        )
    }

    static func today(
        now: Date = Date(),
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> LocalDay {
        LocalDay(date: now, timeZone: timeZone)
    }

    static func tomorrow(
        now: Date = Date(),
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> LocalDay {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let next = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        return LocalDay(date: next, timeZone: timeZone)
    }

    func date(
        hour: Int = 12,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        ))
    }

    func addingDays(
        _ value: Int,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> LocalDay {
        guard let source = date(timeZone: timeZone) else { return self }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let result = calendar.date(byAdding: .day, value: value, to: source) ?? source
        return LocalDay(date: result, timeZone: timeZone)
    }

    func formatted(
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent,
        includeYear: Bool = false
    ) -> String {
        guard let value = date(timeZone: timeZone) else {
            return "\(month) 月 \(day) 日"
        }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = includeYear ? "yyyy 年 M 月 d 日" : "M 月 d 日"
        return formatter.string(from: value)
    }

    func weekday(
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        guard let value = date(timeZone: timeZone) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "EEEE"
        return formatter.string(from: value)
    }

    static func < (lhs: LocalDay, rhs: LocalDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

extension LocalDay {
    /// 界面文案全部是中文，日期也固定用中文格式，
    /// 否则在英文系统上会出现「今天 / Wednesday」这样的中英混排。
    static let displayLocale = Locale(identifier: "zh_Hans")
}
