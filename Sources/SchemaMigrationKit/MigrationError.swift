/// Everything the registry refuses to do, and why.
///
/// The cases carry the contract, the versions, and the violations rather than a
/// message string, so a caller can branch on the reason instead of matching
/// text.
///
/// The type deliberately does **not** conform to `CustomStringConvertible`.
/// With fourteen cases a hand-written `description` switch would exceed the
/// cyclomatic-complexity limit, and the obvious shortcut — `String(describing:
/// self)` inside `description` — recurses forever, because `String(describing:)`
/// dispatches straight back to `description`. Leaving the conformance off gets
/// the same readable reflection output (`unknownVersion(contract: weather.alert,
/// version: v4)`) from plain interpolation, with no recursion to trip over.
public enum MigrationError: Error, Sendable, Hashable {

    case blankContractID
    case duplicateContract(ContractID)
    case unknownContract(ContractID)
    case contractHasNoVersions(ContractID)
    case duplicateVersion(contract: ContractID, version: SchemaVersion)
    case unknownVersion(contract: ContractID, version: SchemaVersion)
    case stepNotAdjacent(contract: ContractID, from: SchemaVersion, to: SchemaVersion)
    case duplicateStep(contract: ContractID, from: SchemaVersion, to: SchemaVersion)
    case noMigrationPath(contract: ContractID, from: SchemaVersion, to: SchemaVersion)
    case lossyMigrationRefused(contract: ContractID, from: SchemaVersion, to: SchemaVersion, drops: [String])
    case versionSunset(contract: ContractID, version: SchemaVersion, status: VersionStatus)
    case sourcePayloadInvalid(contract: ContractID, version: SchemaVersion, violations: [SchemaViolation])
    case postconditionViolated(
        contract: ContractID,
        step: String,
        version: SchemaVersion,
        violations: [SchemaViolation]
    )
    case stepFailed(contract: ContractID, from: SchemaVersion, to: SchemaVersion, message: String)
}
