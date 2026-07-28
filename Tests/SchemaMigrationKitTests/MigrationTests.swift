import XCTest
@testable import SchemaMigrationKit

final class MigrationTests: XCTestCase {

    func testPlanWalksAdjacentVersions() async throws {
        let registry = try await Fixtures.fullRegistry()
        let path = try await registry.plan(Fixtures.alert, from: 1, to: 3)
        XCTAssertEqual(path.stepCount, 2)
        XCTAssertEqual(path.direction, .upgrade)
        XCTAssertEqual(path.contract, Fixtures.alert)
        XCTAssertEqual(path.description, "v1 -> v3 (2 steps)")
        XCTAssertTrue(path.droppedFields.isEmpty)
    }

    func testPlanReversesForADowngrade() async throws {
        let registry = try await Fixtures.fullRegistry()
        let path = try await registry.plan(Fixtures.alert, from: 3, to: 1)
        XCTAssertEqual(path.steps.map(\.label), ["v3 -> v2", "v2 -> v1"])
        XCTAssertEqual(path.direction, .downgrade)
        XCTAssertEqual(path.droppedFields, ["confidence", "issuedAtTick"])
    }

    func testPlanForOneHopSaysStepNotSteps() async throws {
        let registry = try await Fixtures.fullRegistry()
        let path = try await registry.plan(Fixtures.alert, from: 1, to: 2)
        XCTAssertEqual(path.description, "v1 -> v2 (1 step)")
    }

    func testPlanForTheSameVersionIsIdentity() async throws {
        let registry = try await Fixtures.fullRegistry()
        let path = try await registry.plan(Fixtures.alert, from: 2, to: 2)
        XCTAssertTrue(path.isIdentity)
        XCTAssertEqual(path.direction, .upgrade)
        XCTAssertEqual(path.description, "v2 -> v2 (0 steps)")
    }

    func testPlanRejectsUnknownEndpoints() async throws {
        let registry = try await Fixtures.fullRegistry()
        await assertThrows(MigrationError.unknownVersion(contract: Fixtures.alert, version: 9)) {
            _ = try await registry.plan(Fixtures.alert, from: 9, to: 1)
        }
        await assertThrows(MigrationError.unknownVersion(contract: Fixtures.alert, version: 9)) {
            _ = try await registry.plan(Fixtures.alert, from: 1, to: 9)
        }
    }

    func testPlanRejectsAMissingHop() async throws {
        let registry = SchemaRegistry()
        try await registry.register(Fixtures.definition())
        try await registry.registerStep(Fixtures.upTo2(), for: Fixtures.alert)
        await assertThrows(MigrationError.noMigrationPath(contract: Fixtures.alert, from: 1, to: 3)) {
            _ = try await registry.plan(Fixtures.alert, from: 1, to: 3)
        }
    }

    func testCoverageReportsGapsInBothDirections() async throws {
        let registry = SchemaRegistry()
        try await registry.register(Fixtures.definition())
        try await registry.registerStep(Fixtures.upTo2(), for: Fixtures.alert)
        let coverage = try await registry.coverage(of: Fixtures.alert)
        XCTAssertEqual(coverage.versions, [1, 2, 3])
        XCTAssertEqual(coverage.upgradeGaps, [VersionGap(from: 2, to: 3)])
        XCTAssertEqual(coverage.downgradeGaps, [VersionGap(from: 2, to: 1), VersionGap(from: 3, to: 2)])
        XCTAssertFalse(coverage.canUpgradeThroughout)
        XCTAssertFalse(coverage.canDowngradeThroughout)
        XCTAssertEqual(
            coverage.description,
            "weather.alert [v1 -> v2 -> v3] upgrade gaps 1, downgrade gaps 2"
        )
    }

    func testCoverageIsCompleteWhenEveryHopExists() async throws {
        let registry = try await Fixtures.fullRegistry()
        let coverage = try await registry.coverage(of: Fixtures.alert)
        XCTAssertTrue(coverage.canUpgradeThroughout)
        XCTAssertTrue(coverage.canDowngradeThroughout)
    }

    func testCompatibilityThroughTheRegistryRecordsTheCheck() async throws {
        let recorder = InMemoryMigrationEventRecorder()
        let registry = try await Fixtures.fullRegistry(recorder: recorder)
        let verdict = try await registry.compatibility(of: Fixtures.alert, from: 2, to: 3)
        let events = await recorder.recorded()
        XCTAssertTrue(verdict.isBreaking)
        XCTAssertEqual(
            events.last?.kind,
            .compatibilityChecked(Fixtures.alert, from: 2, to: 3, breaking: 2)
        )
    }

    func testUpgradeAcrossTwoHopsValidatesAndArrives() async throws {
        let registry = try await Fixtures.fullRegistry()
        let result = try await registry.migrate(Fixtures.payloadV1, of: Fixtures.alert, from: 1, to: 3)
        XCTAssertEqual(result.payload["severity"], .string("high"))
        XCTAssertEqual(result.payload["issuedAtTick"], .integer(7))
        XCTAssertEqual(result.payload["confidence"], .double(0.5))
        XCTAssertEqual(result.appliedSteps, 2)
        XCTAssertEqual(result.direction, .upgrade)
        XCTAssertTrue(result.droppedFields.isEmpty)
    }

    func testMigratingToTheSameVersionReusesThePayload() async throws {
        let recorder = InMemoryMigrationEventRecorder()
        let registry = try await Fixtures.fullRegistry(recorder: recorder)
        let result = try await registry.migrate(Fixtures.payloadV1, of: Fixtures.alert, from: 1, to: 1)
        let stats = await registry.statistics()
        let events = await recorder.recorded()
        XCTAssertEqual(result.payload, Fixtures.payloadV1)
        XCTAssertEqual(result.appliedSteps, 0)
        XCTAssertEqual(stats.inPlaceReuses, 1)
        XCTAssertEqual(events.last?.kind, .reusedInPlace(Fixtures.alert, version: 1))
    }

    func testAnInvalidSourcePayloadIsRefusedBeforeAnyStepRuns() async throws {
        let registry = try await Fixtures.fullRegistry()
        let broken: [String: FieldValue] = ["city": .string("Shimla")]
        await assertThrows(
            MigrationError.sourcePayloadInvalid(
                contract: Fixtures.alert,
                version: 1,
                violations: [
                    .missingRequiredField("headline"),
                    .missingRequiredField("severity")
                ]
            )
        ) {
            _ = try await registry.migrate(broken, of: Fixtures.alert, from: 1, to: 2)
        }
    }

    func testASunsetTargetIsRefusedButMigratingAwayFromItIsNot() async throws {
        let registry = try await Fixtures.fullRegistry()
        try await registry.deprecate(
            Fixtures.alert,
            version: 1,
            notice: DeprecationNotice(deprecatedAt: 100, sunsetAt: 200)
        )
        await assertThrows(
            MigrationError.versionSunset(contract: Fixtures.alert, version: 1, status: .sunset(since: 200))
        ) {
            _ = try await registry.migrate(
                Fixtures.payloadV3,
                of: Fixtures.alert,
                from: 3,
                to: 1,
                at: 250,
                allowingLoss: true
            )
        }
        let escape = try await registry.migrate(
            Fixtures.payloadV1,
            of: Fixtures.alert,
            from: 1,
            to: 3,
            at: 250
        )
        XCTAssertEqual(escape.appliedSteps, 2)
    }

    func testALossyPathIsRefusedUnlessTheCallerOptsIn() async throws {
        let recorder = InMemoryMigrationEventRecorder()
        let registry = try await Fixtures.fullRegistry(recorder: recorder)
        await assertThrows(
            MigrationError.lossyMigrationRefused(
                contract: Fixtures.alert,
                from: 3,
                to: 1,
                drops: ["confidence", "issuedAtTick"]
            )
        ) {
            _ = try await registry.migrate(Fixtures.payloadV3, of: Fixtures.alert, from: 3, to: 1)
        }
        let allowed = try await registry.migrate(
            Fixtures.payloadV3,
            of: Fixtures.alert,
            from: 3,
            to: 1,
            allowingLoss: true
        )
        let stats = await registry.statistics()
        let events = await recorder.recorded()
        XCTAssertNil(allowed.payload["confidence"])
        XCTAssertNil(allowed.payload["issuedAtTick"])
        XCTAssertEqual(allowed.payload["severity"], .integer(4))
        XCTAssertEqual(allowed.droppedFields, ["confidence", "issuedAtTick"])
        XCTAssertEqual(stats.fieldsDropped, 2)
        XCTAssertEqual(
            events.last?.kind,
            .droppedFields(Fixtures.alert, from: 3, to: 1, fields: ["confidence", "issuedAtTick"])
        )
    }

    func testADowngradeThatDropsNothingNeedsNoOptIn() async throws {
        let registry = SchemaRegistry()
        try await registry.register(Fixtures.definition())
        let clean = PayloadMigration(from: 2, to: 1) { payload in
            var next = payload
            next["confidence"] = nil
            return next
        }
        try await registry.registerStep(clean, for: Fixtures.alert)
        var payload = Fixtures.payloadV1
        payload["confidence"] = .double(0.9)
        let result = try await registry.migrate(payload, of: Fixtures.alert, from: 2, to: 1)
        XCTAssertEqual(result.direction, .downgrade)
        XCTAssertTrue(result.droppedFields.isEmpty)
    }

    func testAStepThatDoesNotProduceWhatItPromisedIsCaught() async throws {
        let recorder = InMemoryMigrationEventRecorder()
        let registry = SchemaRegistry(recorder: recorder)
        try await registry.register(Fixtures.definition())
        try await registry.registerStep(PayloadMigration(from: 1, to: 2) { $0 }, for: Fixtures.alert)
        try await registry.registerStep(PayloadMigration(from: 2, to: 3) { $0 }, for: Fixtures.alert)
        await assertThrows(
            MigrationError.postconditionViolated(
                contract: Fixtures.alert,
                step: "v2 -> v3",
                version: 3,
                violations: [
                    .missingRequiredField("issuedAtTick"),
                    .typeMismatch(field: "severity", expected: .string, actual: .integer)
                ]
            )
        ) {
            _ = try await registry.migrate(Fixtures.payloadV1, of: Fixtures.alert, from: 1, to: 3)
        }
        let events = await recorder.recorded()
        XCTAssertEqual(
            events.last?.kind,
            .postconditionFailed(Fixtures.alert, version: 3, violations: 2)
        )
    }

    func testAStepThatThrowsIsReportedWithItsEndpoints() async throws {
        let recorder = InMemoryMigrationEventRecorder()
        let registry = SchemaRegistry(recorder: recorder)
        try await registry.register(Fixtures.definition())
        let angry = PayloadMigration(from: 1, to: 2) { _ in throw TestFailure.boom }
        try await registry.registerStep(angry, for: Fixtures.alert)
        await assertThrows(
            MigrationError.stepFailed(contract: Fixtures.alert, from: 1, to: 2, message: "boom")
        ) {
            _ = try await registry.migrate(Fixtures.payloadV1, of: Fixtures.alert, from: 1, to: 2)
        }
        let events = await recorder.recorded()
        XCTAssertEqual(events.last?.kind, .stepThrew(Fixtures.alert, from: 1, to: 2))
    }

    func testMigrateRefusesWhenNoPathExists() async throws {
        let recorder = InMemoryMigrationEventRecorder()
        let registry = SchemaRegistry(recorder: recorder)
        try await registry.register(Fixtures.definition())
        await assertThrows(
            MigrationError.noMigrationPath(contract: Fixtures.alert, from: 1, to: 2)
        ) {
            _ = try await registry.migrate(Fixtures.payloadV1, of: Fixtures.alert, from: 1, to: 2)
        }
        let events = await recorder.recorded()
        XCTAssertEqual(events.last?.kind, .refusedNoPath(Fixtures.alert, from: 1, to: 2))
    }

    func testARegistryWithoutARecorderStillMigrates() async throws {
        let registry = try await Fixtures.fullRegistry()
        let result = try await registry.migrate(Fixtures.payloadV1, of: Fixtures.alert, from: 1, to: 2)
        let stats = await registry.statistics()
        XCTAssertEqual(result.appliedSteps, 1)
        XCTAssertEqual(stats.migrations, 1)
        XCTAssertEqual(stats.contracts, 1)
        XCTAssertEqual(stats.steps, 4)
        XCTAssertEqual(stats.refusals, 0)
    }
}
