import XCTest
@testable import SchemaMigrationKit

final class RegistrationTests: XCTestCase {

    func testRegisterRejectsABlankName() async {
        let registry = SchemaRegistry()
        let definition = ContractDefinition(
            id: "  ",
            versions: [ContractVersionDefinition(version: 1, schema: Fixtures.v1)]
        )
        await assertThrows(MigrationError.blankContractID) {
            try await registry.register(definition)
        }
    }

    func testRegisterRejectsADuplicateContract() async throws {
        let registry = SchemaRegistry()
        try await registry.register(Fixtures.definition())
        await assertThrows(MigrationError.duplicateContract(Fixtures.alert)) {
            try await registry.register(Fixtures.definition())
        }
    }

    func testRegisterRejectsAContractWithNoVersions() async {
        let registry = SchemaRegistry()
        await assertThrows(MigrationError.contractHasNoVersions("empty")) {
            try await registry.register(ContractDefinition(id: "empty", versions: []))
        }
    }

    func testRegisterRejectsDuplicateVersions() async {
        let registry = SchemaRegistry()
        let definition = ContractDefinition(
            id: "dup",
            versions: [
                ContractVersionDefinition(version: 1, schema: Fixtures.v1),
                ContractVersionDefinition(version: 1, schema: Fixtures.v2)
            ]
        )
        await assertThrows(MigrationError.duplicateVersion(contract: "dup", version: 1)) {
            try await registry.register(definition)
        }
    }

    func testRegisterStepRejectsAnUnknownContract() async {
        let registry = SchemaRegistry()
        await assertThrows(MigrationError.unknownContract(Fixtures.alert)) {
            try await registry.registerStep(Fixtures.upTo2(), for: Fixtures.alert)
        }
    }

    func testRegisterStepRejectsUnknownVersions() async throws {
        let registry = SchemaRegistry()
        try await registry.register(Fixtures.definition())
        let fromNowhere = PayloadMigration(from: 9, to: 1) { $0 }
        await assertThrows(MigrationError.unknownVersion(contract: Fixtures.alert, version: 9)) {
            try await registry.registerStep(fromNowhere, for: Fixtures.alert)
        }
        let toNowhere = PayloadMigration(from: 1, to: 9) { $0 }
        await assertThrows(MigrationError.unknownVersion(contract: Fixtures.alert, version: 9)) {
            try await registry.registerStep(toNowhere, for: Fixtures.alert)
        }
    }

    func testRegisterStepRejectsAShortcutAcrossTwoVersions() async throws {
        let registry = SchemaRegistry()
        try await registry.register(Fixtures.definition())
        let shortcut = PayloadMigration(from: 1, to: 3) { $0 }
        await assertThrows(MigrationError.stepNotAdjacent(contract: Fixtures.alert, from: 1, to: 3)) {
            try await registry.registerStep(shortcut, for: Fixtures.alert)
        }
    }

    func testRegisterStepRejectsAStepThatGoesNowhere() async throws {
        let registry = SchemaRegistry()
        try await registry.register(Fixtures.definition())
        let identity = PayloadMigration(from: 2, to: 2) { $0 }
        await assertThrows(MigrationError.stepNotAdjacent(contract: Fixtures.alert, from: 2, to: 2)) {
            try await registry.registerStep(identity, for: Fixtures.alert)
        }
    }

    func testRegisterStepRejectsADuplicateHop() async throws {
        let registry = SchemaRegistry()
        try await registry.register(Fixtures.definition())
        try await registry.registerStep(Fixtures.upTo2(), for: Fixtures.alert)
        await assertThrows(MigrationError.duplicateStep(contract: Fixtures.alert, from: 1, to: 2)) {
            try await registry.registerStep(Fixtures.upTo2(), for: Fixtures.alert)
        }
    }

    func testLookupsReturnRegisteredState() async throws {
        let registry = try await Fixtures.fullRegistry()
        let schema = try await registry.schema(of: Fixtures.alert, version: 2)
        let versions = try await registry.versions(of: Fixtures.alert)
        let status = try await registry.status(of: Fixtures.alert, version: 1, at: 5)
        XCTAssertEqual(schema, Fixtures.v2)
        XCTAssertEqual(versions, [1, 2, 3])
        XCTAssertEqual(status, .active)
    }

    func testLookupsRejectUnknownContractAndVersion() async throws {
        let registry = try await Fixtures.fullRegistry()
        await assertThrows(MigrationError.unknownContract("nope")) {
            _ = try await registry.schema(of: "nope", version: 1)
        }
        await assertThrows(MigrationError.unknownVersion(contract: Fixtures.alert, version: 8)) {
            _ = try await registry.schema(of: Fixtures.alert, version: 8)
        }
    }

    func testDeprecateMarksTheVersionAndRejectsUnknownOnes() async throws {
        let registry = try await Fixtures.fullRegistry()
        try await registry.deprecate(
            Fixtures.alert,
            version: 1,
            notice: DeprecationNotice(deprecatedAt: 100, sunsetAt: 200)
        )
        let status = try await registry.status(of: Fixtures.alert, version: 1, at: 250)
        XCTAssertEqual(status, .sunset(since: 200))
        await assertThrows(MigrationError.unknownVersion(contract: Fixtures.alert, version: 8)) {
            try await registry.deprecate(Fixtures.alert, version: 8, notice: DeprecationNotice(deprecatedAt: 1))
        }
    }
}
