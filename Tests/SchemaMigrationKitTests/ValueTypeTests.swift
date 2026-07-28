import XCTest
@testable import SchemaMigrationKit

final class ValueTypeTests: XCTestCase {

    func testSchemaVersionClampsBelowOne() {
        XCTAssertEqual(SchemaVersion(0).number, 1)
        XCTAssertEqual(SchemaVersion(-9).number, 1)
        XCTAssertEqual(SchemaVersion(4).number, 4)
    }

    func testSchemaVersionOrderingAndDescription() {
        let first: SchemaVersion = 1
        let second: SchemaVersion = 2
        XCTAssertTrue(first < second)
        XCTAssertFalse(second < first)
        XCTAssertEqual(second.description, "v2")
    }

    func testContractIDBlankDetection() {
        let blank = ContractID("   ")
        let empty = ContractID("")
        let named: ContractID = "weather.alert"
        XCTAssertTrue(blank.isBlank)
        XCTAssertTrue(empty.isBlank)
        XCTAssertFalse(named.isBlank)
        XCTAssertEqual(named.description, "weather.alert")
        XCTAssertEqual(named.rawValue, "weather.alert")
    }

    func testFieldValueKindsCoverEveryCase() {
        XCTAssertEqual(FieldValue.string("a").kind, .string)
        XCTAssertEqual(FieldValue.integer(1).kind, .integer)
        XCTAssertEqual(FieldValue.double(1.5).kind, .double)
        XCTAssertEqual(FieldValue.boolean(true).kind, .boolean)
        XCTAssertEqual(FieldValue.array([]).kind, .array)
        XCTAssertEqual(FieldValue.object([:]).kind, .object)
        XCTAssertEqual(FieldValue.null.kind, .null)
    }

    func testFieldTypeDescription() {
        XCTAssertEqual(FieldType.string.description, "string")
        XCTAssertEqual(FieldType.integer.description, "integer")
    }

    func testFieldValueDescriptionRendersEveryCase() {
        XCTAssertEqual(FieldValue.string("hi").description, "\"hi\"")
        XCTAssertEqual(FieldValue.integer(3).description, "3")
        XCTAssertEqual(FieldValue.double(0.5).description, "0.5")
        XCTAssertEqual(FieldValue.boolean(true).description, "true")
        XCTAssertEqual(FieldValue.boolean(false).description, "false")
        XCTAssertEqual(FieldValue.null.description, "null")
        XCTAssertEqual(FieldValue.array([.integer(1), .null]).description, "[1, null]")
        let object = FieldValue.object(["b": .integer(2), "a": .integer(1)])
        XCTAssertEqual(object.description, "{a: 1, b: 2}")
    }

    func testFieldValueRenderSortsKeys() {
        let rendered = FieldValue.render(["z": .integer(1), "a": .string("x")])
        XCTAssertEqual(rendered, "a: \"x\", z: 1")
    }

    func testFieldDefinitionConvenienceConstructors() {
        let required = FieldDefinition.required("city", .string)
        let optional = FieldDefinition.optional("confidence", .double)
        let explicit = FieldDefinition(name: "city", type: .string, isRequired: true)
        XCTAssertTrue(required.isRequired)
        XCTAssertFalse(optional.isRequired)
        XCTAssertEqual(required, explicit)
        XCTAssertEqual(optional.type, .double)
        XCTAssertEqual(optional.name, "confidence")
    }

    func testSchemaViolationFieldAndDescription() {
        let missing = SchemaViolation.missingRequiredField("city")
        let mismatch = SchemaViolation.typeMismatch(field: "severity", expected: .integer, actual: .string)
        XCTAssertEqual(missing.field, "city")
        XCTAssertEqual(mismatch.field, "severity")
        XCTAssertEqual(missing.description, "missing required field 'city'")
        XCTAssertEqual(mismatch.description, "field 'severity' expected integer but found string")
    }

    func testBreakingChangeDescriptions() {
        XCTAssertEqual(BreakingChange.fieldRemoved("a").description, "field 'a' removed")
        XCTAssertEqual(
            BreakingChange.fieldTypeChanged(field: "a", from: .integer, to: .string).description,
            "field 'a' changed type integer -> string"
        )
        XCTAssertEqual(BreakingChange.requiredFieldAdded("b").description, "required field 'b' added")
        XCTAssertEqual(
            BreakingChange.optionalFieldMadeRequired("c").description,
            "field 'c' became required"
        )
    }

    func testCompatibilityVerdictAccessors() {
        let compatible = CompatibilityVerdict.compatible
        let breaking = CompatibilityVerdict.breaking([.fieldRemoved("a")])
        XCTAssertFalse(compatible.isBreaking)
        XCTAssertTrue(breaking.isBreaking)
        XCTAssertTrue(compatible.changes.isEmpty)
        XCTAssertEqual(breaking.changes.count, 1)
        XCTAssertEqual(compatible.description, "compatible")
        XCTAssertEqual(breaking.description, "breaking (field 'a' removed)")
    }

    func testVersionStatusDescriptions() {
        XCTAssertEqual(VersionStatus.active.description, "active")
        XCTAssertEqual(VersionStatus.deprecated(since: 3).description, "deprecated since tick 3")
        XCTAssertEqual(VersionStatus.sunset(since: 9).description, "sunset since tick 9")
        XCTAssertFalse(VersionStatus.active.isSunset)
        XCTAssertFalse(VersionStatus.deprecated(since: 3).isSunset)
        XCTAssertTrue(VersionStatus.sunset(since: 9).isSunset)
    }

    func testDeprecationNoticeClampsSunsetAndReportsStatus() {
        let clamped = DeprecationNotice(deprecatedAt: 100, sunsetAt: 20)
        XCTAssertEqual(clamped.sunsetAt, 100)
        let notice = DeprecationNotice(deprecatedAt: 100, sunsetAt: 200)
        XCTAssertEqual(notice.status(at: 50), .active)
        XCTAssertEqual(notice.status(at: 150), .deprecated(since: 100))
        XCTAssertEqual(notice.status(at: 200), .sunset(since: 200))
        let openEnded = DeprecationNotice(deprecatedAt: 10)
        XCTAssertNil(openEnded.sunsetAt)
        XCTAssertEqual(openEnded.status(at: 999), .deprecated(since: 10))
    }

    func testContractVersionDefinitionStatus() {
        let plain = ContractVersionDefinition(version: 1, schema: Fixtures.v1)
        XCTAssertEqual(plain.status(at: 1_000), .active)
        let deprecated = plain.deprecated(by: DeprecationNotice(deprecatedAt: 5))
        XCTAssertEqual(deprecated.status(at: 6), .deprecated(since: 5))
        XCTAssertEqual(deprecated.version, 1)
        XCTAssertEqual(deprecated.schema, Fixtures.v1)
    }

    func testContractDefinitionOrders() {
        let definition = ContractDefinition(
            id: "c",
            versions: [
                ContractVersionDefinition(version: 3, schema: Fixtures.v3),
                ContractVersionDefinition(version: 1, schema: Fixtures.v1)
            ]
        )
        XCTAssertEqual(definition.ordered().map(\.version), [1, 3])
        XCTAssertEqual(definition.id, "c")
        XCTAssertEqual(definition.versions.count, 2)
    }

    func testMigrationDirectionDescriptions() {
        XCTAssertEqual(MigrationDirection.upgrade.description, "upgrade")
        XCTAssertEqual(MigrationDirection.downgrade.description, "downgrade")
    }

    func testLossPolicyDroppedFieldsAndDescription() {
        XCTAssertTrue(LossPolicy.lossless.droppedFields.isEmpty)
        XCTAssertEqual(LossPolicy.lossy(drops: ["b", "a"]).droppedFields, ["a", "b"])
        XCTAssertEqual(LossPolicy.lossless.description, "lossless")
        XCTAssertEqual(LossPolicy.lossy(drops: ["b", "a"]).description, "lossy(a, b)")
    }

    func testMigrationStepDirectionAndLabel() throws {
        let up = Fixtures.upTo2()
        let down = Fixtures.downTo1()
        XCTAssertEqual(up.direction, .upgrade)
        XCTAssertEqual(down.direction, .downgrade)
        XCTAssertEqual(up.label, "v1 -> v2")
        XCTAssertEqual(up.loss, .lossless)
        let migrated = try up.migrate(Fixtures.payloadV1)
        XCTAssertEqual(migrated["confidence"], .double(0.5))
    }

    func testVersionGapDescription() {
        XCTAssertEqual(VersionGap(from: 1, to: 2).description, "v1 -> v2")
    }

    func testMigrationStatisticsDescription() {
        let stats = MigrationStatistics(
            contracts: 1,
            steps: 2,
            migrations: 3,
            inPlaceReuses: 4,
            refusals: 5,
            fieldsDropped: 6
        )
        XCTAssertEqual(
            stats.description,
            "contracts 1, steps 2, migrations 3, reused 4, refusals 5, fields dropped 6"
        )
    }

    func testMigrationEventDescription() {
        let event = MigrationEvent(sequence: 4, kind: .reusedInPlace("c", version: 2))
        XCTAssertEqual(event.sequence, 4)
        XCTAssertEqual(event.description, "#4 reusedInPlace(c, version: v2)")
        XCTAssertEqual(event.kind, .reusedInPlace("c", version: 2))
    }

    func testInMemoryRecorderStoresInOrder() async {
        let recorder = InMemoryMigrationEventRecorder()
        await recorder.record(MigrationEvent(sequence: 1, kind: .reusedInPlace("c", version: 1)))
        await recorder.record(MigrationEvent(sequence: 2, kind: .reusedInPlace("c", version: 2)))
        let events = await recorder.recorded()
        let count = await recorder.count()
        XCTAssertEqual(events.map(\.sequence), [1, 2])
        XCTAssertEqual(count, 2)
    }
}
