import SchemaMigrationKit

@main
struct Demo {

    static func main() async {
        print("SchemaMigrationKit demo — versioned contracts for structured output")
        print(String(repeating: "=", count: 72))
        let recorder = InMemoryMigrationEventRecorder()
        let registry = SchemaRegistry(recorder: recorder)
        await setUp(registry)

        await upgradeAcrossTwoVersions(registry)
        await classifyTheChanges(registry)
        await catchAStepThatLies(registry)
        await refuseSilentDataLoss(registry)
        await negotiateAndSunset(registry)

        await report(registry, recorder)
    }

    static func setUp(_ registry: SchemaRegistry) async {
        try? await registry.register(Contracts.alertDefinition())
        try? await registry.register(Contracts.toolDefinition())
        try? await registry.registerStep(Steps.alertUpgradeToV2(), for: Contracts.alert)
        try? await registry.registerStep(Steps.alertUpgradeToV3(issuedAtTick: 42), for: Contracts.alert)
        try? await registry.registerStep(Steps.alertDowngradeToV2(), for: Contracts.alert)
        try? await registry.registerStep(Steps.alertDowngradeToV1(), for: Contracts.alert)
    }

    // MARK: - 1

    static func upgradeAcrossTwoVersions(_ registry: SchemaRegistry) async {
        section("1. A v1 payload from last year's cache, read by today's v3 code")
        let stored: [String: FieldValue] = [
            "city": .string("Shimla"),
            "headline": .string("Heavy snowfall expected overnight"),
            "severity": .integer(4)
        ]
        print("  stored (v1)  {\(FieldValue.render(stored))}")
        do {
            let result = try await registry.migrate(stored, of: Contracts.alert, from: 1, to: 3)
            print("  path         \(result.path)  [\(result.direction)]")
            print("  migrated     {\(FieldValue.render(result.payload))}")
            print("  steps run    \(result.appliedSteps)  dropped \(result.droppedFields.count) field(s)")
        } catch {
            print("  unexpected   \(error)")
        }
    }

    // MARK: - 2

    static func classifyTheChanges(_ registry: SchemaRegistry) async {
        section("2. Is the change breaking? Ask before shipping, not after")
        await printVerdict(registry, from: 1, to: 2)
        await printVerdict(registry, from: 2, to: 3)
    }

    static func printVerdict(_ registry: SchemaRegistry, from: SchemaVersion, to: SchemaVersion) async {
        guard let verdict = try? await registry.compatibility(of: Contracts.alert, from: from, to: to) else {
            return
        }
        print("  \(from) -> \(to)     \(verdict.isBreaking ? "BREAKING" : "compatible")")
        for change in verdict.changes {
            print("               - \(change)")
        }
    }

    // MARK: - 3

    static func catchAStepThatLies(_ registry: SchemaRegistry) async {
        section("3. A step that claims v2 and does not deliver it")
        try? await registry.registerStep(Steps.toolUpgradeForgettingLocale(), for: Contracts.tool)
        let args: [String: FieldValue] = ["query": .string("snow closures near me")]
        do {
            let result = try await registry.migrate(args, of: Contracts.tool, from: 1, to: 2)
            print("  returned     {\(FieldValue.render(result.payload))}  <- should not happen")
        } catch let error as MigrationError {
            print("  refused      \(error)")
            print("  note         the caller never receives the half-migrated payload")
        } catch {
            print("  unexpected   \(error)")
        }
        await catchAStepThatThrows(registry)
    }

    static func catchAStepThatThrows(_ registry: SchemaRegistry) async {
        let second = SchemaRegistry()
        try? await second.register(Contracts.toolDefinition())
        try? await second.registerStep(Steps.toolUpgradeThatThrows(), for: Contracts.tool)
        do {
            _ = try await second.migrate(
                ["query": .string("road status")],
                of: Contracts.tool,
                from: 1,
                to: 2
            )
        } catch let error as MigrationError {
            print("  thrown step  \(error)")
        } catch {
            print("  unexpected   \(error)")
        }
    }

    // MARK: - 4

    static func refuseSilentDataLoss(_ registry: SchemaRegistry) async {
        section("4. Serving a v1 client from a v3 payload")
        let current: [String: FieldValue] = [
            "city": .string("Shimla"),
            "headline": .string("Heavy snowfall expected overnight"),
            "severity": .string("high"),
            "confidence": .double(0.5),
            "issuedAtTick": .integer(42)
        ]
        do {
            _ = try await registry.migrate(current, of: Contracts.alert, from: 3, to: 1)
        } catch let error as MigrationError {
            print("  refused      \(error)")
        } catch {
            print("  unexpected   \(error)")
        }
        do {
            let allowed = try await registry.migrate(
                current,
                of: Contracts.alert,
                from: 3,
                to: 1,
                allowingLoss: true
            )
            print("  allowed      {\(FieldValue.render(allowed.payload))}")
            print("  dropped      \(allowed.droppedFields.joined(separator: ", "))")
        } catch {
            print("  unexpected   \(error)")
        }
    }

    // MARK: - 5

    static func negotiateAndSunset(_ registry: SchemaRegistry) async {
        section("5. Negotiation, deprecation, and the hops nobody registered")
        await printNegotiation(registry, producer: 1, consumer: 3, tick: 0)
        await printNegotiation(registry, producer: 3, consumer: 2, tick: 0)
        let notice = DeprecationNotice(deprecatedAt: 100, sunsetAt: 200)
        try? await registry.deprecate(Contracts.alert, version: 1, notice: notice)
        let status = try? await registry.status(of: Contracts.alert, version: 1, at: 250)
        print("  v1 at 250    \(status.map { "\($0)" } ?? "unknown")")
        await printNegotiation(registry, producer: 2, consumer: 1, tick: 250)
        await printMigrationOutOfSunset(registry)
        if let coverage = try? await registry.coverage(of: Contracts.tool) {
            print("  coverage     \(coverage)")
            print("  missing      \(coverage.downgradeGaps.map(\.description).joined(separator: ", "))")
        }
    }

    static func printNegotiation(
        _ registry: SchemaRegistry,
        producer: SchemaVersion,
        consumer: SchemaVersion,
        tick: Int
    ) async {
        guard let outcome = try? await registry.negotiate(
            Contracts.alert,
            producerVersion: producer,
            consumerVersion: consumer,
            at: tick
        ) else { return }
        print("  \(producer) -> \(consumer) @\(tick)  \(outcome)")
    }

    static func printMigrationOutOfSunset(_ registry: SchemaRegistry) async {
        let stored: [String: FieldValue] = [
            "city": .string("Manali"),
            "headline": .string("Road closed at Rohtang"),
            "severity": .integer(2)
        ]
        do {
            let result = try await registry.migrate(stored, of: Contracts.alert, from: 1, to: 3, at: 250)
            print("  out of v1    ok at tick 250 — \(result.path), severity now "
                + "\(result.payload["severity"].map { "\($0)" } ?? "?")")
        } catch {
            print("  out of v1    \(error)")
        }
    }

    // MARK: - Reporting

    static func report(_ registry: SchemaRegistry, _ recorder: InMemoryMigrationEventRecorder) async {
        section("Audit trail")
        let events = await recorder.recorded()
        for event in events.suffix(8) {
            print("  \(event)")
        }
        print("  … \(events.count) events total")
        section("Statistics")
        print("  \(await registry.statistics())")
    }

    static func section(_ title: String) {
        print("")
        print(title)
        print(String(repeating: "-", count: 72))
    }
}
