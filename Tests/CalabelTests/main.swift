import Foundation

@main
struct AgendaLogicChecks {
    static func main() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var checkCount = 0
        func item(_ id: String = "a", start: TimeInterval = 0, end: TimeInterval = 3_600, allDay: Bool = false) -> CalendarItem {
            CalendarItem(id: id, title: id, start: now.addingTimeInterval(start), end: now.addingTimeInterval(end), calendarTitle: "Work", colorHex: "#5588FF", isAllDay: allDay)
        }
        func expect(_ condition: @autoclosure () -> Bool, _ rule: String) {
            checkCount += 1
            guard condition() else { fputs("FAIL: \(rule)\n", stderr); exit(1) }
        }

        expect(AgendaLogic.moment(in: [item()], now: now) == .inProgress(item()), "start is in progress")
        expect(AgendaLogic.moment(in: [item()], now: now.addingTimeInterval(3_600)) == .none, "end is exclusive")
        let ongoing = item("ongoing", start: -600, end: 900)
        let next = item("next", start: 60, end: 1_000)
        expect(AgendaLogic.moment(in: [next, ongoing], now: now) == .inProgress(ongoing), "ongoing wins over upcoming")
        let sooner = item("sooner", start: 300, end: 600)
        let later = item("later", start: 900, end: 1_800)
        let allDay = item("all-day", start: -100, end: 99_000, allDay: true)
        expect(AgendaLogic.moment(in: [later, allDay, sooner], now: now) == .upcoming(sooner), "soonest timed event wins")
        let sameTimeA = item("a-first", start: 300, end: 900)
        let sameTimeB = item("b-second", start: 300, end: 1_200)
        expect(AgendaLogic.moment(in: [sameTimeB, sameTimeA], now: now) == .upcoming(sameTimeA), "same-start tie breaks by identifier")
        expect(AgendaLogic.moment(in: [allDay], now: now) == .none, "all-day does not drive countdown")
        expect(AgendaLogic.moment(in: [], now: now) == .none, "empty event list has no moment")
        expect(AgendaLogic.countdown(for: .upcoming(item(start: 30)), now: now) == "1분 후", "positive sub-minute duration rounds up")
        expect(AgendaLogic.countdown(for: .upcoming(item(start: 18_540)), now: now) == "5시간 9분 후", "hour and minute label")
        expect(AgendaLogic.countdown(for: .inProgress(item()), now: now) == "1시간 남음", "ongoing label")
        expect(AgendaLogic.countdown(for: .none, now: now) == "일정 없음", "empty label")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let days = AgendaLogic.agendaDays(from: now, calendar: calendar)
        expect(days.count == 7, "agenda covers seven local days")
        let overnight = item("overnight", start: -60, end: 86_460)
        let groups = AgendaLogic.groupedAgenda([overnight], now: now, calendar: calendar)
        expect(groups[0].events == [overnight] && groups[1].events == [overnight], "overnight event appears in both days")

        let domain = "Calabel.Settings.Test"
        let defaults = UserDefaults(suiteName: domain)!
        defaults.removePersistentDomain(forName: domain)
        var preferences = CalendarPreferences(defaults: defaults)
        expect(preferences.showCalendarColors, "calendar colors default to on")
        preferences.showCalendarColors = false
        expect(!CalendarPreferences(defaults: defaults).showCalendarColors, "calendar color preference persists")
        expect(preferences.menuBarFontSize == 12, "menu bar font size defaults to 12 points")
        expect(preferences.markerTextSpacing == 4, "marker spacing defaults to 4 points")
        expect(preferences.markerThickness == 3, "marker thickness defaults to 3 points")
        expect(preferences.language == .system, "language defaults to system")
        preferences.menuBarFontSize = 16
        preferences.markerTextSpacing = 9
        preferences.markerThickness = 6
        preferences.language = .english
        var restoredPreferences = CalendarPreferences(defaults: defaults)
        expect(restoredPreferences.menuBarFontSize == 16, "menu bar font size persists")
        expect(restoredPreferences.markerTextSpacing == 9, "marker spacing persists")
        expect(restoredPreferences.markerThickness == 6, "marker thickness persists")
        expect(restoredPreferences.language == .english, "language persists")
        restoredPreferences.menuBarFontSize = 30
        restoredPreferences.markerTextSpacing = -3
        restoredPreferences.markerThickness = 0
        expect(CalendarPreferences(defaults: defaults).menuBarFontSize == 18, "menu bar font size clamps to maximum")
        expect(CalendarPreferences(defaults: defaults).markerTextSpacing == 0, "marker spacing clamps to minimum")
        expect(CalendarPreferences(defaults: defaults).markerThickness == 1, "marker thickness clamps to minimum")
        restoredPreferences.markerThickness = 30
        expect(CalendarPreferences(defaults: defaults).markerThickness == 8, "marker thickness clamps to maximum")
        defaults.set(Double.nan, forKey: "menuBarFontSize")
        expect(CalendarPreferences(defaults: defaults).menuBarFontSize == 12, "non-finite stored font size uses default")
        preferences.menuBarFontSize = Double.nan
        expect(CalendarPreferences(defaults: defaults).menuBarFontSize == 12, "non-finite font size writes the default")
        defaults.set("unknown", forKey: "appLanguage")
        expect(CalendarPreferences(defaults: defaults).language == .system, "invalid stored language falls back to system")

        expect(AppLanguage.system.resolved(preferredLanguages: ["ko-KR"]) == .korean, "system Korean preference resolves to Korean")
        expect(AppLanguage.system.resolved(preferredLanguages: ["en-US"]) == .english, "system English preference resolves to English")
        expect(AppLanguage.system.resolved(preferredLanguages: ["fr-FR", "ko-KR"]) == .korean, "system selects first supported preferred language")
        expect(AppLanguage.system.resolved(preferredLanguages: ["fr-FR"]) == .english, "system falls back to English without supported preference")
        expect(AppLanguage.korean.resolved(preferredLanguages: ["en-US"]) == .korean, "explicit Korean overrides system preference")
        expect(AppLanguage.english.resolved(preferredLanguages: ["ko-KR"]) == .english, "explicit English overrides system preference")

        expect(AgendaLogic.durationLabel(from: now, to: now, language: .english) == "0m", "English zero duration")
        expect(AgendaLogic.durationLabel(from: now, to: now.addingTimeInterval(30), language: .english) == "1m", "English sub-minute duration rounds up")
        expect(AgendaLogic.countdown(for: .upcoming(item(start: 18_540)), now: now, language: .english) == "in 5h 9m", "English upcoming countdown")
        expect(AgendaLogic.countdown(for: .inProgress(item(start: -600, end: 2_400)), now: now, language: .english) == "40m left", "English ongoing countdown")
        expect(AgendaLogic.endCountdown(for: item(end: 2_400), now: now, language: .english) == "Ends in 40m", "English end label")
        expect(AgendaLogic.countdown(for: .none, now: now, language: .english) == "No upcoming events", "English empty countdown")
        var dateCalendar = Calendar(identifier: .gregorian)
        dateCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let localizer = CalabelLocalizer(.english)
        let testDate = Date(timeIntervalSince1970: 1_792_627_200)
        expect(localizer.dayHeading(offset: 2, date: testDate, calendar: dateCalendar) == "Oct 22 (Thu)", "English agenda date locale")
        expect(localizer.eventTime(testDate, timeZone: TimeZone(secondsFromGMT: 0)!) == "12:00 AM", "English agenda time locale")
        expect(localizer.text(.today) == "Today" && localizer.text(.tomorrow) == "Tomorrow", "English day headings")
        expect(localizer.eventTitle("  ") == "Untitled event", "English untitled-event placeholder")
        expect(localizer.text(.allDay) == "All day" && localizer.text(.emptyDay) == "No events", "English agenda empty states")
        expect(localizer.text(.accessDeniedExplanation).contains("System Settings"), "English permission state")
        expect(localizer.languageName(.system) == "System" && localizer.languageName(.korean) == "한국어", "localized language choices")

        let linkEvent = CalendarItem(
            id: "store-id/event-id", title: "Link", start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 60),
            calendarTitle: "Work", colorHex: "#5588FF", isAllDay: false,
            calendarItemIdentifier: "calendar-uuid/calendar-id/event-uuid", isRecurring: false
        )
        expect(
            EventURLBuilder.make(for: linkEvent, timeZone: TimeZone(secondsFromGMT: 0)!)?.absoluteString ==
                "ical://ekevent/calendar-uuid/calendar-id/event-uuid?method=show&options=more",
            "Calendar event link uses calendar item identifier"
        )
        let escapedLinkEvent = CalendarItem(
            id: "escaped", title: "Escaped", start: linkEvent.start, end: linkEvent.end,
            calendarTitle: "Work", colorHex: "#5588FF", isAllDay: false,
            calendarItemIdentifier: "calendar?uuid#section%2F/event", isRecurring: false
        )
        expect(
            EventURLBuilder.make(for: escapedLinkEvent)?.absoluteString ==
                "ical://ekevent/calendar%3Fuuid%23section%252F/event?method=show&options=more",
            "event URL identifier escapes query and fragment delimiters while retaining path separators"
        )
        let recurring = CalendarItem(
            id: "recurring-occurrence", title: "Recurring", start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 60),
            calendarTitle: "Work", colorHex: "#5588FF", isAllDay: false,
            calendarItemIdentifier: "calendar-id/event-id", isRecurring: true
        )
        expect(
            EventURLBuilder.make(for: recurring, timeZone: TimeZone(secondsFromGMT: 0)!)?.absoluteString ==
                "ical://ekevent/19700101T000000Z/calendar-id/event-id?method=show&options=more",
            "recurring event link identifies the occurrence in UTC"
        )
        let allDayOccurrence = CalendarItem(
            id: "all-day-occurrence", title: "All day", start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 86_400),
            calendarTitle: "Work", colorHex: "#5588FF", isAllDay: true,
            calendarItemIdentifier: "calendar-id/event-id", isRecurring: true
        )
        expect(
            EventURLBuilder.make(for: allDayOccurrence, timeZone: TimeZone(secondsFromGMT: 9 * 3_600)!)?.absoluteString ==
                "ical://ekevent/19700101T090000Z/calendar-id/event-id?method=show&options=more",
            "all-day recurring event link uses local wall time"
        )
        let unlinked = CalendarItem(
            id: "demo", title: "Demo", start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 60),
            calendarTitle: "Work", colorHex: "#5588FF", isAllDay: false
        )
        expect(EventURLBuilder.make(for: unlinked) == nil, "event without Calendar identifier has no deep link")
        defaults.removePersistentDomain(forName: domain)
        print("PASS: \(checkCount) deterministic checks")
    }
}
