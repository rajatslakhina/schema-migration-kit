import SchemaMigrationKit

/// The demo's contracts, kept apart from the scenarios so the scenarios read as
/// a story rather than a wall of schema literals.
enum Contracts {

    static let alert: ContractID = "weather.alert"
    static let tool: ContractID = "search.tool"

    /// v1 — what the first release of the app asked the model for.
    static let alertV1 = ContractSchema([
        .required("city", .string),
        .required("headline", .string),
        .required("severity", .integer)
    ])

    /// v2 — one optional field added. Additive, so old readers keep working.
    static let alertV2 = ContractSchema([
        .required("city", .string),
        .required("headline", .string),
        .required("severity", .integer),
        .optional("confidence", .double)
    ])

    /// v3 — severity became a band rather than a number, and the payload now
    /// has to say when it was issued. Both changes break a v2 reader.
    static let alertV3 = ContractSchema([
        .required("city", .string),
        .required("headline", .string),
        .required("severity", .string),
        .optional("confidence", .double),
        .required("issuedAtTick", .integer)
    ])

    static let toolV1 = ContractSchema([
        .required("query", .string)
    ])

    static let toolV2 = ContractSchema([
        .required("query", .string),
        .required("locale", .string)
    ])

    static func alertDefinition() -> ContractDefinition {
        ContractDefinition(
            id: alert,
            versions: [
                ContractVersionDefinition(version: 1, schema: alertV1),
                ContractVersionDefinition(version: 2, schema: alertV2),
                ContractVersionDefinition(version: 3, schema: alertV3)
            ]
        )
    }

    static func toolDefinition() -> ContractDefinition {
        ContractDefinition(
            id: tool,
            versions: [
                ContractVersionDefinition(version: 1, schema: toolV1),
                ContractVersionDefinition(version: 2, schema: toolV2)
            ]
        )
    }
}
