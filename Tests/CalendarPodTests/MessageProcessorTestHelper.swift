import Foundation
@testable import pod_dezzw_calendar

// MARK: - Helper Functions for Bencode Testing
func checkStatusDone(_ status: Bencode?) -> Bool {
    guard case .list(let statusList) = status else { return false }
    return statusList.contains { bencode in
        if case .string("done") = bencode { return true }
        return false
    }
}

func checkStatusError(_ status: Bencode?) -> Bool {
    guard case .list(let statusList) = status else { return false }
    return statusList.contains { bencode in
        if case .string("error") = bencode { return true }
        return false
    }
}

// MARK: - Test Helper for Message Processing
public class MessageProcessorTestHelper {
    
    private let mockService: MockCalendarService
    
    public init(mockService: MockCalendarService) {
        self.mockService = mockService
    }
    
    // MARK: - Message Processing Tests
    
    public func processDescribeMessage() -> Bencode {
        return describeBencode()
    }
    
    public func processAddEventMessage(id: String, args: InvokeArgs) async -> Bencode {
        do {
            try await mockService.addEvent(args: args)
            return .dict([
                "id": .string(id),
                "status": .list([.string("done")]),
                "value": .string("\"ok\""),
            ])
        } catch {
            return .dict([
                "id": .string(id),
                "status": .list([.string("done"), .string("error")]),
                "ex-message": .string(error.localizedDescription),
            ])
        }
    }
    
    public func processListEventsMessage(id: String, args: ListArgs) async -> Bencode {
        do {
            let events = try await mockService.listEvents(args: args)
            return .dict([
                "id": .string(id),
                "status": .list([.string("done")]),
                "value": .string(encodeJSON(events)),
            ])
        } catch {
            return .dict([
                "id": .string(id),
                "status": .list([.string("done"), .string("error")]),
                "ex-message": .string(error.localizedDescription),
            ])
        }
    }
    
    public func processSearchEventsMessage(id: String, args: SearchArgs) async -> Bencode {
        do {
            let events = try await mockService.searchEvents(args: args)
            return .dict([
                "id": .string(id),
                "status": .list([.string("done")]),
                "value": .string(encodeJSON(events)),
            ])
        } catch {
            return .dict([
                "id": .string(id),
                "status": .list([.string("done"), .string("error")]),
                "ex-message": .string(error.localizedDescription),
            ])
        }
    }
    
    // MARK: - Helper Methods
    
    public func createInvokeMessage(
        id: String,
        operation: String,
        args: Encodable
    ) -> Bencode {
        let argsData = try! JSONEncoder().encode(args)
        let argsString = String(data: argsData, encoding: .utf8)!
        
        return .dict([
            "op": .string("invoke"),
            "id": .string(id),
            "var": .string(operation),
            "args": .string(argsString),
        ])
    }
    
    public func createDescribeMessage() -> Bencode {
        return .dict([
            "op": .string("describe"),
        ])
    }
    
    public func createShutdownMessage() -> Bencode {
        return .dict([
            "op": .string("shutdown"),
        ])
    }
}

// MARK: - Message Processing Test Suite
public class MessageProcessorTestSuite {
    
    private let helper: MessageProcessorTestHelper
    private let mockService: MockCalendarService
    
    public init() {
        self.mockService = MockCalendarService()
        self.helper = MessageProcessorTestHelper(mockService: mockService)
    }
    
    public func runAllTests() async -> [TestResult] {
        var results: [TestResult] = []
        
        // Test describe message
        results.append(await testDescribeMessage())
        
        // Test add event message
        results.append(await testAddEventMessage())
        
        // Test list events message
        results.append(await testListEventsMessage())
        
        // Test search events message
        results.append(await testSearchEventsMessage())
        
        // Test error handling
        results.append(await testErrorHandling())
        
        return results
    }
    
    private func testDescribeMessage() async -> TestResult {
        let result = helper.processDescribeMessage()
        
        guard case .dict(let dict) = result else {
            return TestResult(name: "testDescribeMessage", success: false, message: "Expected dict")
        }
        
        let success = dict["format"]?.string == "json" &&
                     dict["namespaces"] != nil &&
                     dict["ops"] != nil
        
        return TestResult(
            name: "testDescribeMessage",
            success: success,
            message: success ? "Describe message processed correctly" : "Describe message format incorrect"
        )
    }
    
    private func testAddEventMessage() async -> TestResult {
        let args = InvokeArgs(
            calendar: "Personal",
            title: "Test Event",
            start: "2024-01-15 10:00",
            end: "2024-01-15 11:00"
        )
        
        let result = await helper.processAddEventMessage(id: "test-id", args: args)
        
        guard case .dict(let dict) = result else {
            return TestResult(name: "testAddEventMessage", success: false, message: "Expected dict")
        }
        
        let success = dict["id"]?.string == "test-id" &&
                     checkStatusDone(dict["status"]) &&
                     dict["value"]?.string == "\"ok\""
        
        return TestResult(
            name: "testAddEventMessage",
            success: success,
            message: success ? "Add event message processed correctly" : "Add event message processing failed"
        )
    }
    
    private func testListEventsMessage() async -> TestResult {
        // First add an event
        let addArgs = InvokeArgs(
            calendar: "Personal",
            title: "Test Event",
            start: "2024-01-15 10:00",
            end: "2024-01-15 11:00"
        )
        _ = await helper.processAddEventMessage(id: "add-id", args: addArgs)
        
        // Then list events
        let listArgs = ListArgs(
            calendar: "Personal",
            start: "2024-01-01 00:00",
            end: "2024-01-31 23:59"
        )
        
        let result = await helper.processListEventsMessage(id: "list-id", args: listArgs)
        
        guard case .dict(let dict) = result else {
            return TestResult(name: "testListEventsMessage", success: false, message: "Expected dict")
        }
        
        let success = dict["id"]?.string == "list-id" &&
                     checkStatusDone(dict["status"]) &&
                     dict["value"]?.string != nil
        
        return TestResult(
            name: "testListEventsMessage",
            success: success,
            message: success ? "List events message processed correctly" : "List events message processing failed"
        )
    }
    
    private func testSearchEventsMessage() async -> TestResult {
        // First add an event
        let addArgs = InvokeArgs(
            calendar: "Personal",
            title: "Meeting Event",
            start: "2024-01-15 10:00",
            end: "2024-01-15 11:00"
        )
        _ = await helper.processAddEventMessage(id: "add-id", args: addArgs)
        
        // Then search events
        let searchArgs = SearchArgs(
            calendar: "Personal",
            start: "2024-01-01 00:00",
            end: "2024-01-31 23:59",
            query: "meeting"
        )
        
        let result = await helper.processSearchEventsMessage(id: "search-id", args: searchArgs)
        
        guard case .dict(let dict) = result else {
            return TestResult(name: "testSearchEventsMessage", success: false, message: "Expected dict")
        }
        
        let success = dict["id"]?.string == "search-id" &&
                     checkStatusDone(dict["status"]) &&
                     dict["value"]?.string != nil
        
        return TestResult(
            name: "testSearchEventsMessage",
            success: success,
            message: success ? "Search events message processed correctly" : "Search events message processing failed"
        )
    }
    
    private func testErrorHandling() async -> TestResult {
        // Set up mock to throw an error
        mockService.setError(.calendarNotFound)
        
        let args = InvokeArgs(
            calendar: "NonExistent",
            title: "Test Event",
            start: "2024-01-15 10:00",
            end: "2024-01-15 11:00"
        )
        
        let result = await helper.processAddEventMessage(id: "error-id", args: args)
        
        guard case .dict(let dict) = result else {
            return TestResult(name: "testErrorHandling", success: false, message: "Expected dict")
        }
        
        let success = dict["id"]?.string == "error-id" &&
                     checkStatusError(dict["status"]) &&
                     dict["ex-message"]?.string != nil
        
        return TestResult(
            name: "testErrorHandling",
            success: success,
            message: success ? "Error handling works correctly" : "Error handling failed"
        )
    }
}

// MARK: - Test Result Structure
public struct TestResult {
    public let name: String
    public let success: Bool
    public let message: String
    
    public init(name: String, success: Bool, message: String) {
        self.name = name
        self.success = success
        self.message = message
    }
}
