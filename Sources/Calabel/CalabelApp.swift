import AppKit
import Combine
import EventKit

@main
@MainActor
struct CalabelApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate(demo: CommandLine.arguments.contains("--demo"))
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store: CalendarStore
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var timer: Timer?
    private var subscriptions = Set<AnyCancellable>()
    private var settingsWindowController: SettingsWindowController?

    init(demo: Bool) {
        store = CalendarStore(demo: demo)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let identifier = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: identifier).count > 1 {
            NSApplication.shared.terminate(nil)
            return
        }
        statusItem.menu = menu
        menu.delegate = self
        store.$events.receive(on: RunLoop.main).sink { [weak self] _ in self?.updateMenu() }.store(in: &subscriptions)
        store.$showCalendarColors.receive(on: RunLoop.main).sink { [weak self] _ in self?.updateMenu() }.store(in: &subscriptions)
        store.$menuBarFontSize.receive(on: RunLoop.main).sink { [weak self] _ in self?.updateMenu() }.store(in: &subscriptions)
        store.$markerTextSpacing.receive(on: RunLoop.main).sink { [weak self] _ in self?.updateMenu() }.store(in: &subscriptions)
        store.$markerThickness.receive(on: RunLoop.main).sink { [weak self] _ in self?.updateMenu() }.store(in: &subscriptions)
        store.$language.receive(on: RunLoop.main).sink { [weak self] _ in self?.updateMenu() }.store(in: &subscriptions)
        store.$connected.receive(on: RunLoop.main).sink { [weak self] _ in self?.updateMenu() }.store(in: &subscriptions)
        store.$accessDenied.receive(on: RunLoop.main).sink { [weak self] _ in self?.updateMenu() }.store(in: &subscriptions)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(refreshAfterWake), name: NSWorkspace.didWakeNotification, object: nil
        )
        NotificationCenter.default.addObserver(self, selector: #selector(refreshAfterWake), name: .NSCalendarDayChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(systemLocaleChanged), name: NSLocale.currentLocaleDidChangeNotification, object: nil)
        updateMenu()
        if CommandLine.arguments.contains("--settings") { openSettings() }
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateMenu() }
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        store.refresh()
        updateMenu()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        store.refresh()
        updateMenu()
    }

    private func updateMenu() {
        let now = Date()
        let localizer = CalabelLocalizer(store.resolvedLanguage)
        let moment = AgendaLogic.moment(in: store.events, now: now)
        menu.removeAllItems()
        let statusText: String
        switch moment {
        case .inProgress(let event): statusText = "\(localizer.eventTitle(event.title)) · \(AgendaLogic.endCountdown(for: event, now: now, language: store.resolvedLanguage))"
        case .upcoming(let event): statusText = "\(localizer.eventTitle(event.title)) · \(AgendaLogic.countdown(for: moment, now: now, language: store.resolvedLanguage))"
        case .none: statusText = store.connected ? localizer.text(.noUpcomingEvents) : localizer.text(.connectPrompt)
        }
        let status = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        if !store.connected {
            let action = NSMenuItem(title: localizer.text(store.accessDenied ? .calendarSettings : .connectButton), action: #selector(connectOrSettings), keyEquivalent: "")
            action.target = self
            menu.addItem(action)
        } else {
            let days = AgendaLogic.groupedAgenda(store.events, now: now)
            let visibleDays = days.enumerated().filter { $0.offset == 0 || !$0.element.events.isEmpty }
            for day in visibleDays {
                let title = localizer.dayHeading(offset: day.offset, date: day.element.day)
                let heading = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                heading.isEnabled = false
                menu.addItem(heading)
                for event in day.element.events {
                    let time: String
                    if event.isAllDay { time = localizer.text(.allDay) }
                    else { time = localizer.eventTime(event.start) }
                    let rowText = "\(time) · \(localizer.eventTitle(event.title))"
                    let row = NSMenuItem(title: rowText, action: #selector(openEvent(_:)), keyEquivalent: "")
                    row.target = self
                    row.representedObject = event
                    if store.showCalendarColors {
                        row.image = CalendarMarker.image(color: NSColor(hex: event.colorHex), thickness: store.markerThickness, height: 17)
                    }
                    menu.addItem(row)
                }
                if day.element.events.isEmpty {
                    let empty = NSMenuItem(title: "    \(localizer.text(.emptyDay))", action: nil, keyEquivalent: "")
                    empty.isEnabled = false
                    menu.addItem(empty)
                }
            }
            menu.addItem(.separator())
        }
        menu.addItem(.separator())
        let openCalendar = NSMenuItem(title: localizer.text(.openCalendar), action: #selector(openCalendarApp), keyEquivalent: "")
        openCalendar.target = self
        menu.addItem(openCalendar)
        let settings = NSMenuItem(title: localizer.text(.settings), action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: localizer.text(.quit), action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        let summary: String
        switch moment {
        case .inProgress(let event), .upcoming(let event): summary = "\(String(localizer.eventTitle(event.title).prefix(22))) · \(AgendaLogic.countdown(for: moment, now: now, language: store.resolvedLanguage))"
        case .none: summary = "Calabel"
        }
        if let button = statusItem.button {
            button.image = statusMarker(moment)
            button.imagePosition = .imageLeft
            button.imageHugsTitle = true
            button.imageScaling = .scaleProportionallyDown
            button.title = summary
            button.font = .systemFont(ofSize: store.menuBarFontSize, weight: .medium)
            button.toolTip = statusText
            button.setAccessibilityLabel(statusText)
        }
    }

    @objc private func connectOrSettings() {
        if store.accessDenied {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") { NSWorkspace.shared.open(url) }
        } else {
            Task { await store.connect(); updateMenu() }
        }
    }

    @objc private func openCalendarApp() {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") else { return }
        NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
    }

    @objc private func openEvent(_ sender: NSMenuItem) {
        guard let event = sender.representedObject as? CalendarItem else { return }
        guard let url = EventURLBuilder.make(for: event), NSWorkspace.shared.open(url) else {
            openCalendarApp()
            return
        }
    }

    @objc private func openSettings() {
        store.refresh()
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(store: store)
        }
        settingsWindowController?.present()
    }

    @objc private func quit() { NSApplication.shared.terminate(nil) }

    @objc private func refreshAfterWake() { store.refresh(); updateMenu() }

    @objc private func systemLocaleChanged() {
        store.systemLanguageDidChange()
        updateMenu()
    }

    private func statusMarker(_ moment: EventMoment) -> NSImage? {
        guard store.showCalendarColors else { return nil }
        let color: NSColor
        switch moment {
        case .inProgress(let event), .upcoming(let event): color = NSColor(hex: event.colorHex)
        case .none: color = .secondaryLabelColor
        }
        return CalendarMarker.image(
            color: color,
            thickness: store.markerThickness,
            height: 17,
            trailingSpacing: store.markerTextSpacing
        )
    }
}

enum CalendarMarker {
    static func image(color: NSColor, thickness: CGFloat, height: CGFloat, trailingSpacing: CGFloat = 0) -> NSImage {
        let size = NSSize(width: thickness + trailingSpacing, height: height)
        let marker = NSImage(size: size, flipped: false) { _ in
            color.setFill()
            let bar = NSRect(x: 0, y: 1, width: thickness, height: max(0, height - 2))
            let radius = min(thickness / 2, 2)
            NSBezierPath(roundedRect: bar, xRadius: radius, yRadius: radius).fill()
            return true
        }
        marker.isTemplate = false
        return marker
    }
}

private extension NSColor {
    convenience init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let value = UInt64(clean, radix: 16) ?? 0x7E8A99
        self.init(red: CGFloat((value >> 16) & 0xff) / 255, green: CGFloat((value >> 8) & 0xff) / 255, blue: CGFloat(value & 0xff) / 255, alpha: 1)
    }
}
