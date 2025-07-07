import Foundation
@testable import pod_dezzw_calendar

// MARK: - Mock Calendar Service
public class MockCalendarService: CalendarServiceProtocol {
    
    // MARK: - Mock Data
    public var mockCalendars: [CalendarInfo] = [
        CalendarInfo(title: "Personal", identifier: "personal-1", allowsContentModifications: true),
        CalendarInfo(title: "Work", identifier: "work-1", allowsContentModifications: true),
        CalendarInfo(title: "Family", identifier: "family-1", allowsContentModifications: false)
    ]
    
    public var mockEvents: [MockEvent] = []
    
    // MARK: - Mock Configuration
    public var shouldGrantAccess: Bool = true
    public var shouldThrowError: CalendarServiceError?
    public var accessRequestDelay: TimeInterval = 0.0
    
    // MARK: - Call Tracking
    public var requestAccessCallCount = 0
    public var addEventCallCount = 0
    public var listEventsCallCount = 0
    public var searchEventsCallCount = 0
    public var getCalendarsCallCount = 0
    
    public var lastAddEventArgs: InvokeArgs?
    public var lastListEventArgs: ListArgs?
    public var lastSearchEventArgs: SearchArgs?
    
    private let dateFormatter: DateFormatter
    
    public init() {
        dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
    }
    
    // MARK: - CalendarServiceProtocol Implementation
    
    public func requestAccess() async throws -> Bool {
        requestAccessCallCount += 1
        
        if accessRequestDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(accessRequestDelay * 1_000_000_000))
        }
        
        if let error = shouldThrowError {
            throw error
        }
        
        return shouldGrantAccess
    }
    
    public func addEvent(args: InvokeArgs) async throws {
        addEventCallCount += 1
        lastAddEventArgs = args
        
        if let error = shouldThrowError {
            throw error
        }
        
        guard shouldGrantAccess else {
            throw CalendarServiceError.accessDenied
        }
        
        guard mockCalendars.contains(where: { $0.title == args.calendar }) else {
            throw CalendarServiceError.calendarNotFound
        }
        
        guard dateFormatter.date(from: args.start) != nil,
              dateFormatter.date(from: args.end) != nil else {
            throw CalendarServiceError.invalidDateFormat
        }
        
        let newEvent = MockEvent(
            id: UUID().uuidString,
            title: args.title,
            start: args.start,
            end: args.end,
            calendar: args.calendar
        )
        
        mockEvents.append(newEvent)
    }
    
    public func listEvents(args: ListArgs) async throws -> [[String: String]] {
        listEventsCallCount += 1
        lastListEventArgs = args
        
        if let error = shouldThrowError {
            throw error
        }
        
        guard shouldGrantAccess else {
            throw CalendarServiceError.accessDenied
        }
        
        guard mockCalendars.contains(where: { $0.title == args.calendar }) else {
            throw CalendarServiceError.calendarNotFound
        }
        
        guard let startDate = dateFormatter.date(from: args.start),
              let endDate = dateFormatter.date(from: args.end) else {
            throw CalendarServiceError.invalidDateFormat
        }
        
        let filteredEvents = mockEvents.filter { event in
            guard event.calendar == args.calendar else { return false }
            
            guard let eventStartDate = dateFormatter.date(from: event.start),
                  let eventEndDate = dateFormatter.date(from: event.end) else {
                return false
            }
            
            return eventStartDate >= startDate && eventEndDate <= endDate
        }
        
        return filteredEvents.map { event in
            [
                "id": event.id,
                "title": event.title,
                "start": event.start,
                "end": event.end,
            ]
        }
    }
    
    public func searchEvents(args: SearchArgs) async throws -> [EventDTO] {
        searchEventsCallCount += 1
        lastSearchEventArgs = args
        
        if let error = shouldThrowError {
            throw error
        }
        
        guard shouldGrantAccess else {
            throw CalendarServiceError.accessDenied
        }
        
        guard mockCalendars.contains(where: { $0.title == args.calendar }) else {
            throw CalendarServiceError.calendarNotFound
        }
        
        guard let startDate = dateFormatter.date(from: args.start),
              let endDate = dateFormatter.date(from: args.end) else {
            throw CalendarServiceError.invalidDateFormat
        }
        
        let filteredEvents = mockEvents.filter { event in
            guard event.calendar == args.calendar else { return false }
            
            guard let eventStartDate = dateFormatter.date(from: event.start),
                  let eventEndDate = dateFormatter.date(from: event.end) else {
                return false
            }
            
            let inDateRange = eventStartDate >= startDate && eventEndDate <= endDate
            let matchesQuery = event.title.localizedCaseInsensitiveContains(args.query)
            
            return inDateRange && matchesQuery
        }
        
        return filteredEvents.map { event in
            EventDTO(
                id: event.id,
                title: event.title,
                start: event.start,
                end: event.end
            )
        }
    }
    
    public func getCalendars() async throws -> [CalendarInfo] {
        getCalendarsCallCount += 1
        
        if let error = shouldThrowError {
            throw error
        }
        
        guard shouldGrantAccess else {
            throw CalendarServiceError.accessDenied
        }
        
        return mockCalendars
    }
    
    // MARK: - Test Helper Methods
    
    public func reset() {
        mockEvents.removeAll()
        requestAccessCallCount = 0
        addEventCallCount = 0
        listEventsCallCount = 0
        searchEventsCallCount = 0
        getCalendarsCallCount = 0
        lastAddEventArgs = nil
        lastListEventArgs = nil
        lastSearchEventArgs = nil
        shouldGrantAccess = true
        shouldThrowError = nil
        accessRequestDelay = 0.0
    }
    
    public func addMockEvent(_ event: MockEvent) {
        mockEvents.append(event)
    }
    
    public func setAccessDenied() {
        shouldGrantAccess = false
    }
    
    public func setError(_ error: CalendarServiceError) {
        shouldThrowError = error
    }
}

// MARK: - Mock Event Structure
public struct MockEvent {
    public let id: String
    public let title: String
    public let start: String
    public let end: String
    public let calendar: String
    
    public init(id: String, title: String, start: String, end: String, calendar: String) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.calendar = calendar
    }
}
