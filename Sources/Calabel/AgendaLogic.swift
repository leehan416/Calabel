import Foundation

struct CalendarItem: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let calendarTitle: String
    let colorHex: String
    let isAllDay: Bool
    let calendarItemIdentifier: String?
    let isRecurring: Bool

    init(
        id: String,
        title: String,
        start: Date,
        end: Date,
        calendarTitle: String,
        colorHex: String,
        isAllDay: Bool,
        calendarItemIdentifier: String? = nil,
        isRecurring: Bool = false
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.calendarTitle = calendarTitle
        self.colorHex = colorHex
        self.isAllDay = isAllDay
        self.calendarItemIdentifier = calendarItemIdentifier
        self.isRecurring = isRecurring
    }

    var isTimed: Bool { !isAllDay }
}

enum EventMoment: Equatable {
    case inProgress(CalendarItem)
    case upcoming(CalendarItem)
    case none
}

enum AgendaLogic {
    static func moment(in events: [CalendarItem], now: Date) -> EventMoment {
        let timed = events.filter { $0.isTimed && $0.start < $0.end }
        if let current = timed
            .filter({ $0.start <= now && now < $0.end })
            .sorted(by: { $0.end == $1.end ? $0.id < $1.id : $0.end < $1.end }).first {
            return .inProgress(current)
        }
        if let next = timed
            .filter({ $0.start > now })
            .sorted(by: { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }).first {
            return .upcoming(next)
        }
        return .none
    }

    static func countdown(for moment: EventMoment, now: Date, language: AppLanguage = .korean) -> String {
        let localizer = CalabelLocalizer(language)
        switch moment {
        case .none:
            return localizer.text(.emptyCountdown)
        case .inProgress(let event):
            return localizer.remainingCountdown(from: now, to: event.end)
        case .upcoming(let event):
            return localizer.upcomingCountdown(from: now, to: event.start)
        }
    }

    static func endCountdown(for event: CalendarItem, now: Date, language: AppLanguage = .korean) -> String {
        CalabelLocalizer(language).endCountdown(from: now, to: event.end)
    }

    static func durationLabel(from start: Date, to end: Date, language: AppLanguage = .korean) -> String {
        CalabelLocalizer(language).durationLabel(from: start, to: end)
    }

    static func agendaDays(from now: Date, calendar: Calendar = .current) -> [Date] {
        let today = calendar.startOfDay(for: now)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    static func groupedAgenda(
        _ events: [CalendarItem], now: Date, calendar: Calendar = .current
    ) -> [(day: Date, events: [CalendarItem])] {
        agendaDays(from: now, calendar: calendar).map { day in
            let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            let dayEvents = events.filter { $0.start < nextDay && $0.end > day }
                .sorted { $0.start < $1.start }
            return (day, dayEvents)
        }
    }
}
