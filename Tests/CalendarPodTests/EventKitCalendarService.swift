import Foundation
import EventKit
@testable import pod_dezzw_calendar

// MARK: - Real EventKit Implementation
public class EventKitCalendarService: CalendarServiceProtocol {
    private let store = EKEventStore()
    private let dateFormatter: DateFormatter
    
    public init() {
        dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
    }
    
    public func requestAccess() async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            store.requestAccess(to: .event) { granted, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    public func addEvent(args: InvokeArgs) async throws {
        let granted = try await requestAccess()
        guard granted else {
            throw CalendarServiceError.accessDenied
        }
        
        guard let startDate = dateFormatter.date(from: args.start),
              let endDate = dateFormatter.date(from: args.end) else {
            throw CalendarServiceError.invalidDateFormat
        }
        
        guard let calendar = store.calendars(for: .event).first(where: { $0.title == args.calendar }) else {
            throw CalendarServiceError.calendarNotFound
        }
        
        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = args.title
        event.startDate = startDate
        event.endDate = endDate
        
        try store.save(event, span: .thisEvent)
    }
    
    public func listEvents(args: ListArgs) async throws -> [[String: String]] {
        let granted = try await requestAccess()
        guard granted else {
            throw CalendarServiceError.accessDenied
        }
        
        guard let startDate = dateFormatter.date(from: args.start),
              let endDate = dateFormatter.date(from: args.end) else {
            throw CalendarServiceError.invalidDateFormat
        }
        
        guard let calendar = store.calendars(for: .event).first(where: { $0.title == args.calendar }) else {
            throw CalendarServiceError.calendarNotFound
        }
        
        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: [calendar])
        let events = store.events(matching: predicate)
        
        return events.map { event in
            [
                "id": event.eventIdentifier ?? "",
                "title": event.title ?? "",
                "start": dateFormatter.string(from: event.startDate),
                "end": dateFormatter.string(from: event.endDate),
            ]
        }
    }
    
    public func searchEvents(args: SearchArgs) async throws -> [EventDTO] {
        let granted = try await requestAccess()
        guard granted else {
            throw CalendarServiceError.accessDenied
        }
        
        guard let startDate = dateFormatter.date(from: args.start),
              let endDate = dateFormatter.date(from: args.end) else {
            throw CalendarServiceError.invalidDateFormat
        }
        
        guard let calendar = store.calendars(for: .event).first(where: { $0.title == args.calendar }) else {
            throw CalendarServiceError.calendarNotFound
        }
        
        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: [calendar])
        let events = store.events(matching: predicate)
        
        return events
            .filter { $0.title.localizedCaseInsensitiveContains(args.query) }
            .map { event in
                EventDTO(
                    id: event.eventIdentifier ?? "",
                    title: event.title ?? "",
                    start: dateFormatter.string(from: event.startDate),
                    end: dateFormatter.string(from: event.endDate)
                )
            }
    }
    
    public func getCalendars() async throws -> [CalendarInfo] {
        let granted = try await requestAccess()
        guard granted else {
            throw CalendarServiceError.accessDenied
        }
        
        return store.calendars(for: .event).map { calendar in
            CalendarInfo(
                title: calendar.title,
                identifier: calendar.calendarIdentifier,
                allowsContentModifications: calendar.allowsContentModifications
            )
        }
    }
}
