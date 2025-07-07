import XCTest

@testable import pod_dezzw_calendar

final class MessageProcessorTests: XCTestCase {

    var testSuite: MessageProcessorTestSuite!

    override func setUp() {
        super.setUp()
        testSuite = MessageProcessorTestSuite()
    }

    override func tearDown() {
        testSuite = nil
        super.tearDown()
    }

    func testFullMessageProcessingSuite() async throws {
        // When
        let results = await testSuite.runAllTests()

        // Then
        for result in results {
            XCTAssertTrue(result.success, "\(result.name) failed: \(result.message)")
        }

        // Print summary
        let successCount = results.filter { $0.success }.count
        let totalCount = results.count

        print("Test Summary: \(successCount)/\(totalCount) tests passed")

        for result in results {
            let status = result.success ? "✅" : "❌"
            print("\(status) \(result.name): \(result.message)")
        }
    }

    func testIndividualMessageProcessing() async throws {
        // Given
        let mockService = MockCalendarService()
        let helper = MessageProcessorTestHelper(mockService: mockService)

        // Test describe message
        let describeResult = helper.processDescribeMessage()
        guard case .dict(let describeDict) = describeResult else {
            XCTFail("Expected dict from describe")
            return
        }
        XCTAssertEqual(describeDict["format"]?.string, "json")

        // Test add event message
        let addArgs = InvokeArgs(
            calendar: "Personal",
            title: "Test Event",
            start: "2024-01-15 10:00",
            end: "2024-01-15 11:00"
        )
        let addResult = await helper.processAddEventMessage(id: "add-1", args: addArgs)
        guard case .dict(let addDict) = addResult else {
            XCTFail("Expected dict from add event")
            return
        }
        XCTAssertEqual(addDict["id"]?.string, "add-1")
        XCTAssertTrue(checkStatusDone(addDict["status"]))

        // Test list events message
        let listArgs = ListArgs(
            calendar: "Personal",
            start: "2024-01-01 00:00",
            end: "2024-01-31 23:59"
        )
        let listResult = await helper.processListEventsMessage(id: "list-1", args: listArgs)
        guard case .dict(let listDict) = listResult else {
            XCTFail("Expected dict from list events")
            return
        }
        XCTAssertEqual(listDict["id"]?.string, "list-1")
        XCTAssertTrue(checkStatusDone(listDict["status"]))
        XCTAssertNotNil(listDict["value"]?.string)

        // Test search events message
        let searchArgs = SearchArgs(
            calendar: "Personal",
            start: "2024-01-01 00:00",
            end: "2024-01-31 23:59",
            query: "test"
        )
        let searchResult = await helper.processSearchEventsMessage(id: "search-1", args: searchArgs)
        guard case .dict(let searchDict) = searchResult else {
            XCTFail("Expected dict from search events")
            return
        }
        XCTAssertEqual(searchDict["id"]?.string, "search-1")
        XCTAssertTrue(checkStatusDone(searchDict["status"]))
        XCTAssertNotNil(searchDict["value"]?.string)
    }

    func testMessageCreation() {
        // Given
        let mockService = MockCalendarService()
        let helper = MessageProcessorTestHelper(mockService: mockService)

        // Test describe message creation
        let describeMessage = helper.createDescribeMessage()
        guard case .dict(let describeDict) = describeMessage else {
            XCTFail("Expected dict from describe message")
            return
        }
        XCTAssertEqual(describeDict["op"]?.string, "describe")

        // Test invoke message creation
        let args = InvokeArgs(
            calendar: "Personal",
            title: "Test Event",
            start: "2024-01-15 10:00",
            end: "2024-01-15 11:00"
        )
        let invokeMessage = helper.createInvokeMessage(
            id: "test-id",
            operation: "calendar/add-event",
            args: args
        )
        guard case .dict(let invokeDict) = invokeMessage else {
            XCTFail("Expected dict from invoke message")
            return
        }
        XCTAssertEqual(invokeDict["op"]?.string, "invoke")
        XCTAssertEqual(invokeDict["id"]?.string, "test-id")
        XCTAssertEqual(invokeDict["var"]?.string, "calendar/add-event")
        XCTAssertNotNil(invokeDict["args"]?.string)

        // Test shutdown message creation
        let shutdownMessage = helper.createShutdownMessage()
        guard case .dict(let shutdownDict) = shutdownMessage else {
            XCTFail("Expected dict from shutdown message")
            return
        }
        XCTAssertEqual(shutdownDict["op"]?.string, "shutdown")
    }

    func testErrorMessageHandling() async {
        // Given
        let mockService = MockCalendarService()
        mockService.setError(.accessDenied)
        let helper = MessageProcessorTestHelper(mockService: mockService)

        // When
        let args = InvokeArgs(
            calendar: "Personal",
            title: "Test Event",
            start: "2024-01-15 10:00",
            end: "2024-01-15 11:00"
        )
        let result = await helper.processAddEventMessage(id: "error-test", args: args)

        // Then
        guard case .dict(let dict) = result else {
            XCTFail("Expected dict from error response")
            return
        }

        XCTAssertEqual(dict["id"]?.string, "error-test")
        guard case .list(let status) = dict["status"] else {
            XCTFail("Expected status list")
            return
        }

        XCTAssertTrue(
            status.contains {
                if case .string("done") = $0 { return true }
                return false
            })
        XCTAssertTrue(
            status.contains {
                if case .string("error") = $0 { return true }
                return false
            })
        XCTAssertEqual(dict["ex-message"]?.string, "Access denied to calendar")
    }

    func testConcurrentMessageProcessing() async {
        // Given
        let args1 = InvokeArgs(
            calendar: "Personal", title: "Event 1", start: "2024-01-15 10:00",
            end: "2024-01-15 11:00")
        let args2 = InvokeArgs(
            calendar: "Personal", title: "Event 2", start: "2024-01-15 12:00",
            end: "2024-01-15 13:00")
        let args3 = InvokeArgs(
            calendar: "Personal", title: "Event 3", start: "2024-01-15 14:00",
            end: "2024-01-15 15:00")

        // When - Process messages concurrently with separate mock services to avoid data races
        async let result1 = MessageProcessorTestHelper(mockService: MockCalendarService())
            .processAddEventMessage(id: "concurrent-1", args: args1)
        async let result2 = MessageProcessorTestHelper(mockService: MockCalendarService())
            .processAddEventMessage(id: "concurrent-2", args: args2)
        async let result3 = MessageProcessorTestHelper(mockService: MockCalendarService())
            .processAddEventMessage(id: "concurrent-3", args: args3)

        let results = await [result1, result2, result3]

        // Then
        XCTAssertEqual(results.count, 3)

        for (index, result) in results.enumerated() {
            guard case .dict(let dict) = result else {
                XCTFail("Expected dict from concurrent result \(index)")
                continue
            }

            XCTAssertEqual(dict["id"]?.string, "concurrent-\(index + 1)")
            XCTAssertTrue(checkStatusDone(dict["status"]))
            XCTAssertEqual(dict["value"]?.string, "\"ok\"")
        }

        // Each concurrent operation should succeed independently
        // We can't verify the total count since each uses its own mock service
    }
}
