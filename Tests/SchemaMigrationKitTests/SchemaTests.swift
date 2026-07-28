import XCTest
@testable import SchemaMigrationKit

final class SchemaTests: XCTestCase {

    func testValidateAcceptsAWellFormedPayload() {
        XCTAssertTrue(Fixtures.v1.validate(Fixtures.payloadV1).isEmpty)
    }

    func testValidateReportsMissingAndMismatchedSortedByField() {
        let payload: [String: FieldValue] = ["severity": .string("high")]
        let violations = Fixtures.v1.validate(payload)
        XCTAssertEqual(violations, [
            .missingRequiredField("city"),
            .missingRequiredField("headline"),
            .typeMismatch(field: "severity", expected: .integer, actual: .string)
        ])
    }

    func testValidateIgnoresUnknownFieldsAndAbsentOptionals() {
        var payload = Fixtures.payloadV1
        payload["somethingNewer"] = .boolean(true)
        XCTAssertTrue(Fixtures.v2.validate(payload).isEmpty)
    }

    func testValidateFlagsAnOptionalFieldOfTheWrongType() {
        var payload = Fixtures.payloadV1
        payload["confidence"] = .string("high")
        XCTAssertEqual(Fixtures.v2.validate(payload), [
            .typeMismatch(field: "confidence", expected: .double, actual: .string)
        ])
    }

    func testNamesAndDefinitionLookup() {
        XCTAssertEqual(Fixtures.v1.names(), ["city", "headline", "severity"])
        XCTAssertEqual(Fixtures.v1.definition(named: "city")?.type, .string)
        XCTAssertNil(Fixtures.v1.definition(named: "missing"))
        XCTAssertEqual(Fixtures.v1.fields.count, 3)
    }

    func testAdditiveChangeIsCompatible() {
        XCTAssertEqual(Fixtures.v1.compatibility(to: Fixtures.v2), .compatible)
    }

    func testTypeChangeAndRequiredAdditionAreBreaking() {
        let verdict = Fixtures.v2.compatibility(to: Fixtures.v3)
        XCTAssertEqual(verdict.changes, [
            .fieldTypeChanged(field: "severity", from: .integer, to: .string),
            .requiredFieldAdded("issuedAtTick")
        ])
    }

    func testRemovalIsBreaking() {
        let stripped = ContractSchema([.required("city", .string)])
        XCTAssertEqual(Fixtures.v1.compatibility(to: stripped).changes, [
            .fieldRemoved("headline"),
            .fieldRemoved("severity")
        ])
    }

    func testTighteningAnOptionalFieldIsBreaking() {
        let tightened = ContractSchema([
            .required("city", .string),
            .required("headline", .string),
            .required("severity", .integer),
            .required("confidence", .double)
        ])
        XCTAssertEqual(Fixtures.v2.compatibility(to: tightened).changes, [
            .optionalFieldMadeRequired("confidence")
        ])
    }

    func testAddingAnOptionalFieldIsNotBreaking() {
        let widened = ContractSchema(Fixtures.v1.fields + [.optional("note", .string)])
        XCTAssertFalse(Fixtures.v1.compatibility(to: widened).isBreaking)
    }
}
