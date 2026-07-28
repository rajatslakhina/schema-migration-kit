import SchemaMigrationKit

enum Fixtures {

    static let alert: ContractID = "weather.alert"

    static let v1 = ContractSchema([
        .required("city", .string),
        .required("headline", .string),
        .required("severity", .integer)
    ])

    static let v2 = ContractSchema([
        .required("city", .string),
        .required("headline", .string),
        .required("severity", .integer),
        .optional("confidence", .double)
    ])

    static let v3 = ContractSchema([
        .required("city", .string),
        .required("headline", .string),
        .required("severity", .string),
        .optional("confidence", .double),
        .required("issuedAtTick", .integer)
    ])

    static func definition() -> ContractDefinition {
        ContractDefinition(
            id: alert,
            versions: [
                ContractVersionDefinition(version: 1, schema: v1),
                ContractVersionDefinition(version: 2, schema: v2),
                ContractVersionDefinition(version: 3, schema: v3)
            ]
        )
    }

    static func upTo2() -> PayloadMigration {
        PayloadMigration(from: 1, to: 2) { payload in
            var next = payload
            next["confidence"] = .double(0.5)
            return next
        }
    }

    static func upTo3() -> PayloadMigration {
        PayloadMigration(from: 2, to: 3) { payload in
            var next = payload
            if case .integer(let level) = payload["severity"] {
                next["severity"] = .string(level >= 3 ? "high" : "low")
            }
            next["issuedAtTick"] = .integer(7)
            return next
        }
    }

    static func downTo2() -> PayloadMigration {
        PayloadMigration(from: 3, to: 2, loss: .lossy(drops: ["issuedAtTick"])) { payload in
            var next = payload
            next["severity"] = .integer(payload["severity"] == .string("high") ? 4 : 1)
            next["issuedAtTick"] = nil
            return next
        }
    }

    static func downTo1() -> PayloadMigration {
        PayloadMigration(from: 2, to: 1, loss: .lossy(drops: ["confidence"])) { payload in
            var next = payload
            next["confidence"] = nil
            return next
        }
    }

    static let payloadV1: [String: FieldValue] = [
        "city": .string("Shimla"),
        "headline": .string("Snow"),
        "severity": .integer(4)
    ]

    static let payloadV3: [String: FieldValue] = [
        "city": .string("Shimla"),
        "headline": .string("Snow"),
        "severity": .string("high"),
        "confidence": .double(0.5),
        "issuedAtTick": .integer(7)
    ]

    /// A registry with all three versions and all four steps registered.
    static func fullRegistry(
        recorder: (any MigrationEventRecording)? = nil
    ) async throws -> SchemaRegistry {
        let registry = SchemaRegistry(recorder: recorder)
        try await registry.register(definition())
        try await registry.registerStep(upTo2(), for: alert)
        try await registry.registerStep(upTo3(), for: alert)
        try await registry.registerStep(downTo2(), for: alert)
        try await registry.registerStep(downTo1(), for: alert)
        return registry
    }
}

enum TestFailure: Error {
    case boom
}
