import XCTest
@testable import ContainerDesk

/// Covers the ISO date parsing that drives RelativeTimeText (live "N ago" labels).
final class FormatterTests: XCTestCase {

    func testParsesPlainISO8601() {
        let date = Formatters.date(fromISO: "2026-07-04T04:07:35Z")
        XCTAssertNotNil(date)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date!)
        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 7)
        XCTAssertEqual(parts.day, 4)
        XCTAssertEqual(parts.hour, 4)
        XCTAssertEqual(parts.minute, 7)
        XCTAssertEqual(parts.second, 35)
    }

    func testParsesFractionalSeconds() {
        // Image manifests carry nanosecond precision.
        XCTAssertNotNil(Formatters.date(fromISO: "2026-06-16T00:01:29.967161902Z"))
        XCTAssertNotNil(Formatters.date(fromISO: "2026-06-16T00:01:29.5Z"))
    }

    func testParsesEpochDate() {
        // Built-in network reports 1970-01-01; must parse, not crash or nil out.
        let date = Formatters.date(fromISO: "1970-01-01T00:00:00Z")
        XCTAssertNotNil(date)
        XCTAssertEqual(date!.timeIntervalSince1970, 0, accuracy: 0.001)
    }

    func testParsesTimezoneOffset() {
        XCTAssertNotNil(Formatters.date(fromISO: "2026-07-04T13:07:35+09:00"))
    }

    func testRejectsInvalidInput() {
        XCTAssertNil(Formatters.date(fromISO: nil))
        XCTAssertNil(Formatters.date(fromISO: ""))
        XCTAssertNil(Formatters.date(fromISO: "not a date"))
        XCTAssertNil(Formatters.date(fromISO: "2026-07-04"))          // date only
        XCTAssertNil(Formatters.date(fromISO: "2026-07-04 04:07:35")) // missing T/Z
    }

    func testRecordDatesFeedRelativeText() throws {
        // The exact fields RelativeTimeText consumes must parse from real CLI payloads.
        let containerJSON = """
        [{"configuration":{"id":"a","creationDate":"2026-07-04T04:07:35Z"},"id":"a",
          "status":{"state":"running","startedDate":"2026-07-04T04:07:37Z"}}]
        """
        let container = try JSONDecoder()
            .decode([ContainerRecord].self, from: Data(containerJSON.utf8))[0]
        XCTAssertNotNil(Formatters.date(fromISO: container.configuration.creationDate))
        XCTAssertNotNil(Formatters.date(fromISO: container.status?.startedDate))

        let imageJSON = """
        [{"configuration":{"name":"alpine:latest","creationDate":"2026-06-16T00:00:15Z"},"id":"x"}]
        """
        let image = try JSONDecoder().decode([ImageRecord].self, from: Data(imageJSON.utf8))[0]
        XCTAssertNotNil(Formatters.date(fromISO: image.configuration.creationDate))
    }

    func testBytesFormatting() {
        XCTAssertEqual(Formatters.bytes(nil), "—")
        XCTAssertEqual(Formatters.bytes(0), "—")
        XCTAssertEqual(Formatters.bytes(-1), "—")
        XCTAssertTrue(Formatters.bytes(4_200_000).contains("MB"))
        XCTAssertTrue(Formatters.bytes(549_755_813_888).contains("GB"))
    }
}
