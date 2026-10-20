import EventKit
import Foundation
import Combine

@MainActor
final class CalendarStore: ObservableObject {
    @Published private(set) var events: [CalendarItem] = []
    @Published private(set) var calendars: [EKCalendar] = []
    @Published private(set) var accessGranted = false
    @Published private(set) var accessDenied = false
    @Published private(set) var connected = false
    @Published private(set) var isConnecting = false
    @Published var selectedIDs: Set<String> = [] { didSet { persistSelection(); refresh() } }
    @Published var showCalendarColors = true {
        didSet { preferences.showCalendarColors = showCalendarColors }
    }
    @Published var menuBarFontSize = 12.0 {
        didSet { preferences.menuBarFontSize = menuBarFontSize }
    }
    @Published var markerTextSpacing = 4.0 {
        didSet { preferences.markerTextSpacing = markerTextSpacing }
    }
    @Published var markerThickness = 3.0 {
        didSet { preferences.markerThickness = markerThickness }
    }
    @Published var language: AppLanguage {
        didSet { preferences.language = language }
    }

    private let store = EKEventStore()
    private let defaults = UserDefaults.standard
    private var preferences: CalendarPreferences
    private var observer: NSObjectProtocol?
    private let demo: Bool

    init(demo: Bool) {
        self.demo = demo
        let preferences = CalendarPreferences()
        self.preferences = preferences
        self.showCalendarColors = preferences.showCalendarColors
        self.menuBarFontSize = preferences.menuBarFontSize
        self.markerTextSpacing = preferences.markerTextSpacing
        self.markerThickness = preferences.markerThickness
        self.language = preferences.language
        if demo {
            connected = true
            accessGranted = true
            selectedIDs = ["demo-work", "demo-personal"]
            events = Self.demoEvents()
        } else {
            selectedIDs = Set(defaults.stringArray(forKey: "selectedCalendarIDs") ?? [])
            observer = NotificationCenter.default.addObserver(
                forName: .EKEventStoreChanged, object: store, queue: .main
            ) { [weak self] _ in Task { @MainActor in self?.refresh() } }
            updateAuthorizationState()
            if accessGranted { refresh() }
        }
    }

    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }

    func connect() async {
        guard !demo, !connected, !isConnecting else { return }
        isConnecting = true
        defer { isConnecting = false }
        do {
            let granted = try await store.requestFullAccessToEvents()
            accessGranted = granted
            accessDenied = !granted
            connected = granted
            if granted {
                calendars = store.calendars(for: .event).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
                if defaults.object(forKey: "selectedCalendarIDs") == nil {
                    selectedIDs = Set(calendars.map(\.calendarIdentifier))
                }
                refresh()
            }
        } catch {
            accessDenied = true
        }
    }

    func refresh() {
        guard !demo else { return }
        updateAuthorizationState()
        guard accessGranted else { events = []; return }
        calendars = store.calendars(for: .event).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        if defaults.object(forKey: "selectedCalendarIDs") == nil {
            selectedIDs = Set(calendars.map(\.calendarIdentifier))
        }
        guard !selectedIDs.isEmpty else { events = []; return }
        let chosen = calendars.filter { selectedIDs.contains($0.calendarIdentifier) }
        guard !chosen.isEmpty else { events = []; return }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(7 * 86_400)
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: chosen)
        events = store.events(matching: predicate).map(Self.map).sorted { $0.start < $1.start }
    }

    var resolvedLanguage: AppLanguage { language.resolved() }
    var locale: Locale { resolvedLanguage.locale }

    func systemLanguageDidChange() {
        guard language == .system else { return }
        objectWillChange.send()
    }

    private func updateAuthorizationState() {
        let status = EKEventStore.authorizationStatus(for: .event)
        accessGranted = status == .fullAccess
        accessDenied = status == .denied || status == .restricted || status == .writeOnly
        connected = accessGranted
    }

    private func persistSelection() {
        guard !demo else { return }
        defaults.set(Array(selectedIDs), forKey: "selectedCalendarIDs")
    }

    private static func map(_ event: EKEvent) -> CalendarItem {
        CalendarItem(
            id: event.eventIdentifier ?? UUID().uuidString,
            title: event.title ?? "",
            start: event.startDate,
            end: event.endDate,
            calendarTitle: event.calendar.title,
            colorHex: event.calendar.cgColor.map(Self.hex) ?? "#7E8A99",
            isAllDay: event.isAllDay,
            calendarItemIdentifier: event.calendarItemIdentifier,
            isRecurring: event.hasRecurrenceRules || event.occurrenceDate != nil
        )
    }

    private static func hex(_ color: CGColor) -> String {
        guard let components = color.components, components.count >= 3 else { return "#7E8A99" }
        return String(format: "#%02X%02X%02X", Int(components[0] * 255), Int(components[1] * 255), Int(components[2] * 255))
    }

    private static func demoEvents() -> [CalendarItem] {
        let now = Date()
        let start = now.addingTimeInterval(1_800)
        return [
            CalendarItem(id: "demo-meeting", title: "제품 주간 회의", start: start, end: start.addingTimeInterval(3_600), calendarTitle: "업무", colorHex: "#8B7CFF", isAllDay: false),
            CalendarItem(id: "demo-review", title: "디자인 리뷰", start: start.addingTimeInterval(5_400), end: start.addingTimeInterval(8_100), calendarTitle: "업무", colorHex: "#8B7CFF", isAllDay: false),
            CalendarItem(id: "demo-personal", title: "저녁 약속", start: start.addingTimeInterval(21_600), end: start.addingTimeInterval(24_000), calendarTitle: "개인", colorHex: "#42C9A5", isAllDay: false)
        ]
    }
}
