import Foundation
import EventKit
@testable import pod_dezzw_calendar

// MARK: - Calendar Service Protocol
public protocol CalendarServiceProtocol {
    func requestAccess() async throws -> Bool
    func addEvent(args: InvokeArgs) async throws
    func listEvents(args: ListArgs) async throws -> [[String: String]]
    func searchEvents(args: SearchArgs) async throws -> [EventDTO]
    func getCalendars() async throws -> [CalendarInfo]
}

// MARK: - Calendar Info
public struct CalendarInfo {
    public let title: String
    public let identifier: String
    public let allowsContentModifications: Bool
    
    public init(title: String, identifier: String, allowsContentModifications: Bool = true) {
        self.title = title
        self.identifier = identifier
        self.allowsContentModifications = allowsContentModifications
    }
}

// MARK: - Calendar Service Error
public enum CalendarServiceError: Error, LocalizedError {
    case accessDenied
    case invalidDateFormat
    case calendarNotFound
    case eventNotFound
    case permissionRequired
    
    public var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Access denied to calendar"
        case .invalidDateFormat:
            return "Invalid date format"
        case .calendarNotFound:
            return "Calendar not found"
        case .eventNotFound:
            return "Event not found"
        case .permissionRequired:
            return "Calendar permission required"
        }
    }
}
