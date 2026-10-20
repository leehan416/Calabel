import AppKit
import EventKit
import SwiftUI
import Combine

@MainActor
final class SettingsWindowController: NSWindowController {
    private var subscriptions = Set<AnyCancellable>()

    init(store: CalendarStore) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 460),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = CalabelLocalizer(store.resolvedLanguage).text(.settingsTitle)
        window.contentViewController = NSHostingController(rootView: CalendarSettingsView(store: store))
        window.center()
        super.init(window: window)
        window.isReleasedWhenClosed = false
        store.objectWillChange.receive(on: RunLoop.main).sink { [weak self, weak store] _ in
            guard let store else { return }
            self?.window?.title = CalabelLocalizer(store.resolvedLanguage).text(.settingsTitle)
        }.store(in: &subscriptions)
    }

    required init?(coder: NSCoder) {
        fatalError("Settings window is created in code.")
    }

    func present() {
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

@MainActor
private struct CalendarSettingsView: View {
    @ObservedObject var store: CalendarStore

    private var localizer: CalabelLocalizer { CalabelLocalizer(store.resolvedLanguage) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(localizer.text(.menuBarSection))
                    .font(.headline)
                Picker(localizer.text(.language), selection: $store.language) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(localizer.languageName(language)).tag(language)
                    }
                }
                .accessibilityLabel(localizer.text(.languageAccessibility))
                Toggle(localizer.text(.calendarColors), isOn: $store.showCalendarColors)
                    .toggleStyle(.checkbox)
                    .accessibilityLabel(localizer.text(.calendarColorsAccessibility))

                settingSlider(
                    title: localizer.text(.fontSize),
                    value: $store.menuBarFontSize,
                    range: 10...18,
                    accessibilityLabel: localizer.text(.fontSizeAccessibility)
                )
                settingSlider(
                    title: localizer.text(.markerSpacing),
                    value: $store.markerTextSpacing,
                    range: 0...16,
                    accessibilityLabel: localizer.text(.markerSpacingAccessibility)
                )
                settingSlider(
                    title: localizer.text(.markerThickness),
                    value: $store.markerThickness,
                    range: 1...8,
                    accessibilityLabel: localizer.text(.markerThicknessAccessibility)
                )

                Divider()

                if store.connected {
                    calendarSelection
                } else if store.accessDenied {
                    accessDeniedState
                } else {
                    connectionState
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 420, height: 460)
        .environment(\.locale, store.locale)
    }

    private var calendarSelection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localizer.text(.calendarSelection))
                .font(.headline)
            if store.calendars.isEmpty {
                Text(localizer.text(.noCalendars))
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(store.calendars, id: \.calendarIdentifier) { calendar in
                        Toggle(isOn: selectionBinding(for: calendar)) {
                            HStack(spacing: 9) {
                                if store.showCalendarColors {
                                    Image(nsImage: CalendarMarker.image(
                                        color: calendarNSColor(calendar),
                                        thickness: store.markerThickness,
                                        height: 20
                                    ))
                                    .frame(width: store.markerThickness, height: 20)
                                        .accessibilityHidden(true)
                                }
                                Text(calendar.title)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            .contentShape(Rectangle())
                        }
                        .toggleStyle(.checkbox)
                    }
                }
            }
        }
    }

    private var connectionState: some View {
        VStack(alignment: .leading, spacing: 10) {
                Text(localizer.text(.connectionHeading))
                .font(.headline)
            Text(localizer.text(.connectExplanation))
                .font(.callout)
                .foregroundStyle(.secondary)
            Button {
                Task { await store.connect() }
            } label: {
                if store.isConnecting {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text(localizer.text(.connecting))
                    }
                } else {
                    Text(localizer.text(.connectButton))
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isConnecting)
        }
    }

    private var accessDeniedState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localizer.text(.accessDeniedTitle))
                .font(.headline)
            Text(localizer.text(.accessDeniedExplanation))
                .font(.callout)
                .foregroundStyle(.secondary)
            Button(localizer.text(.openSystemSettings), action: openCalendarPrivacySettings)
                .buttonStyle(.bordered)
        }
    }

    private func settingSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        accessibilityLabel: String
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .frame(width: 150, alignment: .leading)
            Slider(value: value, in: range, step: 1)
                .accessibilityLabel(accessibilityLabel)
            Text("\(Int(value.wrappedValue)) pt")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)
        }
    }

    private func selectionBinding(for calendar: EKCalendar) -> Binding<Bool> {
        Binding(
            get: { store.selectedIDs.contains(calendar.calendarIdentifier) },
            set: { isSelected in
                if isSelected {
                    store.selectedIDs.insert(calendar.calendarIdentifier)
                } else {
                    store.selectedIDs.remove(calendar.calendarIdentifier)
                }
            }
        )
    }

    private func calendarNSColor(_ calendar: EKCalendar) -> NSColor {
        guard let cgColor = calendar.cgColor,
              let color = NSColor(cgColor: cgColor) else {
            return .secondaryLabelColor
        }
        return color
    }

    private func openCalendarPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }
}
