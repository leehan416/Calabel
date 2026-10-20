import Foundation

enum EventURLBuilder {
    static func make(for event: CalendarItem, timeZone: TimeZone = .current) -> URL? {
        guard let identifier = event.calendarItemIdentifier, !identifier.isEmpty else { return nil }

        var path = "/"
        if event.isRecurring {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.timeZone = event.isAllDay ? timeZone : TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            path += "\(formatter.string(from: event.start))/"
        }
        path += identifier

        var components = URLComponents()
        components.scheme = "ical"
        components.host = "ekevent"
        components.path = path
        components.queryItems = [
            URLQueryItem(name: "method", value: "show"),
            URLQueryItem(name: "options", value: "more")
        ]
        return components.url
    }
}
