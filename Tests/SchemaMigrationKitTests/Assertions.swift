import XCTest
@testable import SchemaMigrationKit

extension XCTestCase {

    /// Asserts that `body` throws exactly `expected`.
    ///
    /// A plain function rather than an autoclosure, because `XCTAssertThrowsError`
    /// takes an `@autoclosure` and `await` cannot appear inside one.
    func assertThrows(
        _ expected: MigrationError,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ body: () async throws -> Void
    ) async {
        do {
            try await body()
            XCTFail("expected \(expected) but nothing was thrown", file: file, line: line)
        } catch let error as MigrationError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("expected \(expected) but got \(error)", file: file, line: line)
        }
    }
}
