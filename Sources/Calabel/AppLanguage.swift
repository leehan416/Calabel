import Foundation

enum AppLanguage: String, CaseIterable {
    case system
    case korean = "ko"
    case english = "en"

    func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        switch self {
        case .system:
            for preferred in preferredLanguages {
                let identifier = preferred.lowercased()
                if identifier.hasPrefix("ko") { return .korean }
                if identifier.hasPrefix("en") { return .english }
            }
            return .english
        case .korean, .english:
            return self
        }
    }

    var locale: Locale {
        resolved() == .korean ? Locale(identifier: "ko_KR") : Locale(identifier: "en_US")
    }
}

enum AppTextKey {
    case settingsTitle
    case menuBarSection
    case language
    case languageAccessibility
    case calendarColors
    case calendarColorsAccessibility
    case fontSize
    case fontSizeAccessibility
    case markerSpacing
    case markerSpacingAccessibility
    case markerThickness
    case markerThicknessAccessibility
    case calendarSelection
    case noCalendars
    case connectionHeading
    case connectExplanation
    case connectButton
    case connecting
    case accessDeniedTitle
    case accessDeniedExplanation
    case openSystemSettings
    case noUpcomingEvents
    case emptyCountdown
    case connectPrompt
    case calendarSettings
    case openCalendar
    case settings
    case quit
    case allDay
    case emptyDay
    case today
    case tomorrow
    case untitledEvent
}

struct CalabelLocalizer {
    let language: AppLanguage

    init(_ language: AppLanguage) {
        self.language = language.resolved()
    }

    var locale: Locale { language.locale }

    func text(_ key: AppTextKey) -> String {
        return switch (language, key) {
        case (.korean, .settingsTitle): "설정"
        case (.english, .settingsTitle): "Settings"
        case (.korean, .menuBarSection): "메뉴 막대"
        case (.english, .menuBarSection): "Menu Bar"
        case (.korean, .language): "언어"
        case (.english, .language): "Language"
        case (.korean, .languageAccessibility): "표시 언어"
        case (.english, .languageAccessibility): "Display language"
        case (.korean, .calendarColors): "캘린더 색상 표시"
        case (.english, .calendarColors): "Show calendar colors"
        case (.korean, .calendarColorsAccessibility): "캘린더 색상 표시"
        case (.english, .calendarColorsAccessibility): "Show calendar colors"
        case (.korean, .fontSize): "글자 크기"
        case (.english, .fontSize): "Text size"
        case (.korean, .fontSizeAccessibility): "메뉴 막대 글자 크기"
        case (.english, .fontSizeAccessibility): "Menu bar text size"
        case (.korean, .markerSpacing): "막대와 글자 간격"
        case (.english, .markerSpacing): "Marker spacing"
        case (.korean, .markerSpacingAccessibility): "색상 막대와 글자 사이 간격"
        case (.english, .markerSpacingAccessibility): "Space between marker and text"
        case (.korean, .markerThickness): "색상 막대 두께"
        case (.english, .markerThickness): "Marker thickness"
        case (.korean, .markerThicknessAccessibility): "색상 막대 두께"
        case (.english, .markerThicknessAccessibility): "Marker thickness"
        case (.korean, .calendarSelection): "표시할 캘린더"
        case (.english, .calendarSelection): "Calendars to show"
        case (.korean, .noCalendars): "선택할 캘린더가 없습니다."
        case (.english, .noCalendars): "No calendars available."
        case (.korean, .connectionHeading): "캘린더 연결"
        case (.english, .connectionHeading): "Connect Calendar"
        case (.korean, .connectExplanation): "일정을 표시하려면 캘린더 접근을 허용해 주세요."
        case (.english, .connectExplanation): "Allow calendar access to show your events."
        case (.korean, .connectButton): "캘린더 연결"
        case (.english, .connectButton): "Connect Calendar"
        case (.korean, .connecting): "연결 중"
        case (.english, .connecting): "Connecting"
        case (.korean, .accessDeniedTitle): "캘린더 접근이 꺼져 있어요."
        case (.english, .accessDeniedTitle): "Calendar access is off."
        case (.korean, .accessDeniedExplanation): "시스템 설정에서 Calabel의 캘린더 접근을 허용해 주세요."
        case (.english, .accessDeniedExplanation): "Allow Calabel to access Calendar in System Settings."
        case (.korean, .openSystemSettings): "시스템 설정 열기"
        case (.english, .openSystemSettings): "Open System Settings"
        case (.korean, .noUpcomingEvents): "예정된 일정이 없습니다"
        case (.english, .noUpcomingEvents): "No upcoming events"
        case (.korean, .emptyCountdown): "일정 없음"
        case (.english, .emptyCountdown): "No upcoming events"
        case (.korean, .connectPrompt): "캘린더를 연결해 시작하세요"
        case (.english, .connectPrompt): "Connect a calendar to get started"
        case (.korean, .calendarSettings): "캘린더 설정 열기"
        case (.english, .calendarSettings): "Calendar Settings"
        case (.korean, .openCalendar): "캘린더 열기"
        case (.english, .openCalendar): "Open Calendar"
        case (.korean, .settings): "설정…"
        case (.english, .settings): "Settings…"
        case (.korean, .quit): "Calabel 종료"
        case (.english, .quit): "Quit Calabel"
        case (.korean, .allDay): "종일"
        case (.english, .allDay): "All day"
        case (.korean, .emptyDay): "일정 없음"
        case (.english, .emptyDay): "No events"
        case (.korean, .today): "오늘"
        case (.english, .today): "Today"
        case (.korean, .tomorrow): "내일"
        case (.english, .tomorrow): "Tomorrow"
        case (.korean, .untitledEvent): "제목 없는 일정"
        case (.english, .untitledEvent): "Untitled event"
        case (.system, _): CalabelLocalizer(.english).text(key)
        }
    }

    func languageName(_ language: AppLanguage) -> String {
        return switch language {
        case .system: self.language == .korean ? "시스템 언어" : "System"
        case .korean: "한국어"
        case .english: "English"
        }
    }

    func durationLabel(from start: Date, to end: Date) -> String {
        let interval = max(0, end.timeIntervalSince(start))
        let seconds = interval > 0 && interval < 60 ? 60 : Int(interval)
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        if language == .korean {
            if hours == 0 { return "\(minutes)분" }
            if minutes == 0 { return "\(hours)시간" }
            return "\(hours)시간 \(minutes)분"
        }
        if hours == 0 { return "\(minutes)m" }
        if minutes == 0 { return "\(hours)h" }
        return "\(hours)h \(minutes)m"
    }

    func upcomingCountdown(from now: Date, to start: Date) -> String {
        let duration = durationLabel(from: now, to: start)
        return language == .korean ? "\(duration) 후" : "in \(duration)"
    }

    func remainingCountdown(from now: Date, to end: Date) -> String {
        let duration = durationLabel(from: now, to: end)
        return language == .korean ? "\(duration) 남음" : "\(duration) left"
    }

    func endCountdown(from now: Date, to end: Date) -> String {
        let duration = durationLabel(from: now, to: end)
        return language == .korean ? "\(duration) 후 종료" : "Ends in \(duration)"
    }

    func eventTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? text(.untitledEvent) : title
    }

    func dayHeading(offset: Int, date: Date, calendar: Calendar = .current) -> String {
        switch offset {
        case 0: return text(.today)
        case 1: return text(.tomorrow)
        default:
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = language == .korean ? "M월 d일 (E)" : "MMM d (EEE)"
            return formatter.string(from: date)
        }
    }

    func eventTime(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = language == .korean ? "HH:mm" : "h:mm a"
        return formatter.string(from: date)
    }
}
