import Foundation

struct CalendarPreferences {
    private let defaults: UserDefaults
    private let showColorsKey = "showCalendarColors"
    private let menuBarFontSizeKey = "menuBarFontSize"
    private let markerTextSpacingKey = "markerTextSpacing"
    private let markerThicknessKey = "markerThickness"
    private let languageKey = "appLanguage"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var showCalendarColors: Bool {
        get { defaults.object(forKey: showColorsKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: showColorsKey) }
    }

    var menuBarFontSize: Double {
        get { boundedValue(forKey: menuBarFontSizeKey, default: 12, range: 10...18) }
        set { defaults.set(min(max(newValue.isFinite ? newValue : 12, 10), 18), forKey: menuBarFontSizeKey) }
    }

    var markerTextSpacing: Double {
        get { boundedValue(forKey: markerTextSpacingKey, default: 4, range: 0...16) }
        set { defaults.set(min(max(newValue.isFinite ? newValue : 4, 0), 16), forKey: markerTextSpacingKey) }
    }

    var markerThickness: Double {
        get { boundedValue(forKey: markerThicknessKey, default: 3, range: 1...8) }
        set { defaults.set(min(max(newValue.isFinite ? newValue : 3, 1), 8), forKey: markerThicknessKey) }
    }

    var language: AppLanguage {
        get {
            guard let rawValue = defaults.string(forKey: languageKey),
                  let language = AppLanguage(rawValue: rawValue) else { return .system }
            return language
        }
        set { defaults.set(newValue.rawValue, forKey: languageKey) }
    }

    private func boundedValue(forKey key: String, default fallback: Double, range: ClosedRange<Double>) -> Double {
        guard let value = defaults.object(forKey: key) as? NSNumber else { return fallback }
        let number = value.doubleValue
        guard number.isFinite else { return fallback }
        return min(max(number, range.lowerBound), range.upperBound)
    }
}
