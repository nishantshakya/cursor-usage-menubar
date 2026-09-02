import Foundation

enum WorkingDaysCalculator {
  /// US federal weekday holidays for the given calendar month (weekends excluded; observed dates for fixed holidays).
  static func workingDaysInMonth(year: Int, month: Int, calendar: Calendar = .current) -> Int {
    let holidays = USFederalHolidays.datesInMonth(year: year, month: month, calendar: calendar)
    guard let firstDay = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
          let dayRange = calendar.range(of: .day, in: .month, for: firstDay) else {
      return 0
    }

    var count = 0
    for day in dayRange {
      guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
        continue
      }
      let weekday = calendar.component(.weekday, from: date)
      if weekday == 1 || weekday == 7 { continue }
      let normalized = calendar.startOfDay(for: date)
      if holidays.contains(normalized) { continue }
      count += 1
    }
    return count
  }

  static func workingDaysInCurrentMonth(calendar: Calendar = .current) -> Int {
    let now = Date()
    let year = calendar.component(.year, from: now)
    let month = calendar.component(.month, from: now)
    return workingDaysInMonth(year: year, month: month, calendar: calendar)
  }
}

enum USFederalHolidays {
  static func datesInMonth(year: Int, month: Int, calendar: Calendar = .current) -> Set<Date> {
    var dates: Set<Date> = []
    for holiday in allDates(year: year, calendar: calendar) {
      let components = calendar.dateComponents([.year, .month], from: holiday)
      if components.month == month {
        dates.insert(calendar.startOfDay(for: holiday))
      }
    }
    return dates
  }

  private static func allDates(year: Int, calendar: Calendar) -> [Date] {
    var dates: [Date] = []
    dates.append(observedFixed(month: 1, day: 1, year: year, calendar: calendar))
    dates.append(nthWeekday(month: 1, weekday: 2, nth: 3, year: year, calendar: calendar)) // MLK
    dates.append(nthWeekday(month: 2, weekday: 2, nth: 3, year: year, calendar: calendar)) // Presidents
    dates.append(lastWeekday(month: 5, weekday: 2, year: year, calendar: calendar)) // Memorial
    dates.append(observedFixed(month: 6, day: 19, year: year, calendar: calendar)) // Juneteenth
    dates.append(observedFixed(month: 7, day: 4, year: year, calendar: calendar))
    dates.append(nthWeekday(month: 9, weekday: 2, nth: 1, year: year, calendar: calendar)) // Labor
    dates.append(nthWeekday(month: 10, weekday: 2, nth: 2, year: year, calendar: calendar)) // Columbus
    dates.append(observedFixed(month: 11, day: 11, year: year, calendar: calendar))
    dates.append(nthWeekday(month: 11, weekday: 5, nth: 4, year: year, calendar: calendar)) // Thanksgiving Thu=5
    dates.append(observedFixed(month: 12, day: 25, year: year, calendar: calendar))
    return dates
  }

  private static func observedFixed(month: Int, day: Int, year: Int, calendar: Calendar) -> Date {
    guard var date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
      return Date()
    }
    let weekday = calendar.component(.weekday, from: date)
    if weekday == 7 {
      date = calendar.date(byAdding: .day, value: -1, to: date) ?? date
    } else if weekday == 1 {
      date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
    }
    return calendar.startOfDay(for: date)
  }

  private static func nthWeekday(month: Int, weekday: Int, nth: Int, year: Int, calendar: Calendar) -> Date {
    var count = 0
    guard let range = calendar.range(of: .day, in: .month, for: calendar.date(from: DateComponents(year: year, month: month, day: 1))!) else {
      return Date()
    }
    for day in range {
      guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { continue }
      if calendar.component(.weekday, from: date) == weekday {
        count += 1
        if count == nth {
          return calendar.startOfDay(for: date)
        }
      }
    }
    return Date()
  }

  private static func lastWeekday(month: Int, weekday: Int, year: Int, calendar: Calendar) -> Date {
    guard let first = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
          let range = calendar.range(of: .day, in: .month, for: first) else {
      return Date()
    }
    for day in range.reversed() {
      guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { continue }
      if calendar.component(.weekday, from: date) == weekday {
        return calendar.startOfDay(for: date)
      }
    }
    return Date()
  }
}
