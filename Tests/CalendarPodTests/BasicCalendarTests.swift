import XCTest

@testable import pod_dezzw_calendar

final class CalendarPodTests: XCTestCase {

    var mockService: MockCalendarService!

    override func setUp() {
        super.setUp()
        mockService = MockCalendarService()
    }

    override func tearDown() {
        mockService = nil
        super.tearDown()
    }

    // MARK: - Basic Mock Service Tests

    func testMockServiceRequestAccess() async throws {
        // Given
        mockService.shouldGrantAccess = true

        // When
        let granted = try await mockService.requestAccess()

        // Then
        XCTAssertTrue(granted)
        XCTAssertEqual(mockService.requestAccessCallCount, 1)
    }

    func testMockServiceAddEvent() async throws {
        // Given
        let args = InvokeArgs(
            calendar: "Personal",
            title: "Test Event",
            start: "2024-01-15 10:00",
            end: "2024-01-15 11:00"
        )

        // When
        try await mockService.addEvent(args: args)

        // Then
        XCTAssertEqual(mockService.addEventCallCount, 1)
        XCTAssertEqual(mockService.lastAddEventArgs?.title, "Test Event")
        XCTAssertEqual(mockService.mockEvents.count, 1)
    }

    func testMockServiceListEvents() async throws {
        // Given - Add an event first
        let addArgs = InvokeArgs(
            calendar: "Personal",
            title: "Test Event",
            start: "2024-01-15 10:00",
            end: "2024-01-15 11:00"
        )
        try await mockService.addEvent(args: addArgs)

        let listArgs = ListArgs(
            calendar: "Personal",
            start: "2024-01-01 00:00",
            end: "2024-01-31 23:59"
        )

        // When
        let events = try await mockService.listEvents(args: listArgs)

        // Then
        XCTAssertEqual(mockService.listEventsCallCount, 1)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?["title"], "Test Event")
    }

    func testMockServiceSearchEvents() async throws {
        // Given - Add an event first
        let addArgs = InvokeArgs(
            calendar: "Personal",
            title: "Team Meeting",
            start: "2024-01-15 10:00",
            end: "2024-01-15 11:00"
        )
        try await mockService.addEvent(args: addArgs)

        let searchArgs = SearchArgs(
            calendar: "Personal",
            start: "2024-01-01 00:00",
            end: "2024-01-31 23:59",
            query: "meeting"
        )

        // When
        let events = try await mockService.searchEvents(args: searchArgs)

        // Then
        XCTAssertEqual(mockService.searchEventsCallCount, 1)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.title, "Team Meeting")
    }

    func testMockServiceErrorHandling() async throws {
        // Given
        mockService.setError(.accessDenied)

        let args = InvokeArgs(
            calendar: "Personal",
            title: "Test Event",
            start: "2024-01-15 10:00",
            end: "2024-01-15 11:00"
        )

        // When & Then
        do {
            try await mockService.addEvent(args: args)
            XCTFail("Expected CalendarServiceError.accessDenied")
        } catch CalendarServiceError.accessDenied {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Protocol Tests

    func testProtocolConformance() async throws {
        // Given
        let service: CalendarServiceProtocol = mockService

        // When
        let granted = try await service.requestAccess()

        // Then
        XCTAssertTrue(granted)
    }

    func testProtocolAddAndListWorkflow() async throws {
        // Given
        let service: CalendarServiceProtocol = mockService

        // When - Add event
        let addArgs = InvokeArgs(
            calendar: "Personal",
            title: "Protocol Test Event",
            start: "2024-01-15 10:00",
            end: "2024-01-15 11:00"
        )
        try await service.addEvent(args: addArgs)

        // When - List events
        let listArgs = ListArgs(
            calendar: "Personal",
            start: "2024-01-01 00:00",
            end: "2024-01-31 23:59"
        )
        let events = try await service.listEvents(args: listArgs)

        // Then
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?["title"], "Protocol Test Event")
    }

    // MARK: - Message Processing Tests

    func testMessageProcessorHelper() async throws {
        // Given
        let helper = MessageProcessorTestHelper(mockService: mockService)

        // Test describe message
        let describeResult = helper.processDescribeMessage()
        XCTAssertNotNil(describeResult)

        // Test add event message
        let addArgs = InvokeArgs(
            calendar: "Personal",
            title: "Helper Test Event",
            start: "2024-01-15 10:00",
            end: "2024-01-15 11:00"
        )
        let addResult = await helper.processAddEventMessage(id: "test-id", args: addArgs)
        XCTAssertNotNil(addResult)

        // Verify the event was added
        XCTAssertEqual(mockService.mockEvents.count, 1)
        XCTAssertEqual(mockService.mockEvents.first?.title, "Helper Test Event")
    }

    // MARK: - Bencode Tests

    func testBencodeDescribe() {
        // When
        let result = describeBencode()

        // Then
        guard case .dict(let dict) = result else {
            XCTFail("Expected dict")
            return
        }

        XCTAssertEqual(dict["format"]?.string, "json")
        XCTAssertNotNil(dict["namespaces"])
        XCTAssertNotNil(dict["ops"])
    }

    func testJSONEncoding() {
        // Given
        let event = EventDTO(
            id: "test-id",
            title: "Test Event",
            start: "2024-01-15 10:00",
            end: "2024-01-15 11:00"
        )

        // When
        let json = encodeJSON(event)

        // Then
        XCTAssertTrue(json.contains("test-id"))
        XCTAssertTrue(json.contains("Test Event"))
    }

    // MARK: - Calendar Info Tests

    func testCalendarInfo() {
        // Given
        let calendar = CalendarInfo(
            title: "Test Calendar",
            identifier: "test-id",
            allowsContentModifications: true
        )

        // Then
        XCTAssertEqual(calendar.title, "Test Calendar")
        XCTAssertEqual(calendar.identifier, "test-id")
        XCTAssertTrue(calendar.allowsContentModifications)
    }
}
