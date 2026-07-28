import XCTest
@testable import SchemaMigrationKit

final class NegotiationTests: XCTestCase {

    func testMatchingVersionsNeedNoMigration() async throws {
        let recorder = InMemoryMigrationEventRecorder()
        let registry = try await Fixtures.fullRegistry(recorder: recorder)
        let outcome = try await registry.negotiate(Fixtures.alert, producerVersion: 2, consumerVersion: 2)
        let events = await recorder.recorded()
        guard case .exact(let version) = outcome else {
            return XCTFail("expected an exact match, got \(outcome)")
        }
        XCTAssertEqual(version, 2)
        XCTAssertEqual(outcome.description, "exact v2")
        XCTAssertEqual(
            events.last?.kind,
            .negotiated(Fixtures.alert, producer: 2, consumer: 2, outcome: "exact")
        )
    }

    func testDifferingVersionsAreBridgedByALosslessPath() async throws {
        let registry = try await Fixtures.fullRegistry()
        let outcome = try await registry.negotiate(Fixtures.alert, producerVersion: 1, consumerVersion: 3)
        guard case .migrate(let path) = outcome else {
            return XCTFail("expected a migration, got \(outcome)")
        }
        XCTAssertEqual(path.stepCount, 2)
        XCTAssertEqual(outcome.description, "migrate v1 -> v3 (2 steps)")
    }

    func testAnUnknownProducerVersionIsRefused() async throws {
        let registry = try await Fixtures.fullRegistry()
        let outcome = try await registry.negotiate(Fixtures.alert, producerVersion: 9, consumerVersion: 1)
        XCTAssertEqual(refusal(from: outcome), .producerVersionUnknown(9))
        XCTAssertEqual(outcome.description, "unsupported: producer version v9 is not registered")
    }

    func testAnUnknownConsumerVersionIsRefused() async throws {
        let registry = try await Fixtures.fullRegistry()
        let outcome = try await registry.negotiate(Fixtures.alert, producerVersion: 1, consumerVersion: 9)
        XCTAssertEqual(refusal(from: outcome), .consumerVersionUnknown(9))
        XCTAssertEqual(outcome.description, "unsupported: consumer version v9 is not registered")
    }

    func testAnUnknownContractIsAnError() async throws {
        let registry = try await Fixtures.fullRegistry()
        await assertThrows(MigrationError.unknownContract("nope")) {
            _ = try await registry.negotiate("nope", producerVersion: 1, consumerVersion: 2)
        }
    }

    func testASunsetConsumerIsRefused() async throws {
        let registry = try await Fixtures.fullRegistry()
        try await registry.deprecate(
            Fixtures.alert,
            version: 1,
            notice: DeprecationNotice(deprecatedAt: 100, sunsetAt: 200)
        )
        let outcome = try await registry.negotiate(
            Fixtures.alert,
            producerVersion: 2,
            consumerVersion: 1,
            at: 250
        )
        XCTAssertEqual(refusal(from: outcome), .versionSunset(1, status: .sunset(since: 200)))
        XCTAssertEqual(
            outcome.description,
            "unsupported: consumer version v1 is sunset since tick 200"
        )
    }

    func testADeprecatedButNotSunsetConsumerIsStillServed() async throws {
        let registry = try await Fixtures.fullRegistry()
        try await registry.deprecate(
            Fixtures.alert,
            version: 3,
            notice: DeprecationNotice(deprecatedAt: 100, sunsetAt: 200)
        )
        let outcome = try await registry.negotiate(
            Fixtures.alert,
            producerVersion: 1,
            consumerVersion: 3,
            at: 150
        )
        guard case .migrate = outcome else {
            return XCTFail("expected a migration, got \(outcome)")
        }
    }

    func testALossyBridgeIsNotOfferedAutomatically() async throws {
        let registry = try await Fixtures.fullRegistry()
        let outcome = try await registry.negotiate(Fixtures.alert, producerVersion: 3, consumerVersion: 2)
        XCTAssertEqual(
            refusal(from: outcome),
            .migrationIsLossy(from: 3, to: 2, drops: ["issuedAtTick"])
        )
        XCTAssertEqual(
            outcome.description,
            "unsupported: v3 -> v2 would drop issuedAtTick"
        )
    }

    func testAMissingHopIsRefused() async throws {
        let registry = SchemaRegistry()
        try await registry.register(Fixtures.definition())
        let outcome = try await registry.negotiate(Fixtures.alert, producerVersion: 1, consumerVersion: 2)
        XCTAssertEqual(refusal(from: outcome), .noMigrationPath(from: 1, to: 2))
        XCTAssertEqual(outcome.description, "unsupported: no migration path v1 -> v2")
    }

    func testRefusalsAreCountedAndRecorded() async throws {
        let recorder = InMemoryMigrationEventRecorder()
        let registry = try await Fixtures.fullRegistry(recorder: recorder)
        _ = try await registry.negotiate(Fixtures.alert, producerVersion: 3, consumerVersion: 2)
        let stats = await registry.statistics()
        let events = await recorder.recorded()
        XCTAssertEqual(stats.refusals, 1)
        XCTAssertEqual(
            events.last?.kind,
            .negotiationRefused(Fixtures.alert, reason: .migrationIsLossy(from: 3, to: 2, drops: ["issuedAtTick"]))
        )
    }

    private func refusal(from outcome: NegotiationOutcome) -> NegotiationRefusal? {
        guard case .unsupported(let reason) = outcome else { return nil }
        return reason
    }
}
