import EventKit
import Foundation

public func addEvent(args: InvokeArgs) throws {
    let store = EKEventStore()
    let sema = DispatchSemaphore(value: 0)
    var granted = false
    store.requestAccess(to: .event) { ok, _ in
        granted = ok
        sema.signal()
    }
    sema.wait()

    guard granted else {
        throw NSError(
            domain: "calendar", code: 1, userInfo: [NSLocalizedDescriptionKey: "Access denied"])
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateFormat = "yyyy-MM-dd HH:mm"

    guard let startDate = formatter.date(from: args.start),
        let endDate = formatter.date(from: args.end)
    else {
        throw NSError(
            domain: "calendar", code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Invalid date format"])
    }

    guard
        let calendarUsed = store.calendars(for: .event).first(where: { $0.title == args.calendar })
    else {
        throw NSError(
            domain: "calendar", code: 3, userInfo: [NSLocalizedDescriptionKey: "Calendar not found"]
        )
    }

    let event = EKEvent(eventStore: store)
    event.calendar = calendarUsed
    event.title = args.title
    event.startDate = startDate
    event.endDate = endDate
    try store.save(event, span: .thisEvent)
}

public func listEvents(args: ListArgs) throws -> [[String: String]] {
    let store = EKEventStore()
    let sema = DispatchSemaphore(value: 0)
    var granted = false
    store.requestAccess(to: .event) { ok, _ in
        granted = ok
        sema.signal()
    }
    sema.wait()

    guard granted else {
        throw NSError(
            domain: "calendar", code: 1, userInfo: [NSLocalizedDescriptionKey: "Access denied"])
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateFormat = "yyyy-MM-dd HH:mm"

    guard let startDate = formatter.date(from: args.start),
        let endDate = formatter.date(from: args.end)
    else {
        throw NSError(
            domain: "calendar", code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Invalid date format"])
    }

    guard
        let calendarUsed = store.calendars(for: .event).first(where: { $0.title == args.calendar })
    else {
        throw NSError(
            domain: "calendar", code: 3, userInfo: [NSLocalizedDescriptionKey: "Calendar not found"]
        )
    }

    let predicate = store.predicateForEvents(
        withStart: startDate, end: endDate, calendars: [calendarUsed])
    let events = store.events(matching: predicate)

    let output = events.map { event in
        [
            "id": event.eventIdentifier ?? "",
            "title": event.title ?? "",
            "start": formatter.string(from: event.startDate),
            "end": formatter.string(from: event.endDate),
        ]
    }

    return output
}

public func searchEvents(args: SearchArgs) throws -> [EventDTO] {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateFormat = "yyyy-MM-dd HH:mm"

    guard let startDate = formatter.date(from: args.start),
        let endDate = formatter.date(from: args.end)
    else {
        throw NSError(
            domain: "calendar", code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Invalid date format"])
    }

    let store = EKEventStore()
    let predicate = store.predicateForEvents(
        withStart: startDate, end: endDate,
        calendars: store.calendars(for: .event).filter { $0.title == args.calendar })

    let events = store.events(matching: predicate)

    return
        events
        .filter { $0.title.localizedCaseInsensitiveContains(args.query) }
        .map {
            EventDTO(
                id: $0.eventIdentifier,
                title: $0.title,
                start: formatter.string(from: $0.startDate),
                end: formatter.string(from: $0.endDate))
        }
}
