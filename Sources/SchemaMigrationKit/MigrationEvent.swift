/// One entry in a registry's audit trail.
///
/// Events carry a monotonic sequence number rather than a timestamp. The
/// package never reads a clock, so ordering is the only temporal fact it can
/// honestly report — and ordering is the fact an audit actually needs.
public struct MigrationEvent: Sendable, Hashable, CustomStringConvertible {

    /// What happened.
    public enum Kind: Sendable, Hashable {
        case contractRegistered(ContractID, versions: Int)
        case stepRegistered(ContractID, from: SchemaVersion, to: SchemaVersion)
        case deprecated(ContractID, version: SchemaVersion, at: Int)
        case migrated(ContractID, from: SchemaVersion, to: SchemaVersion, steps: Int)
        case reusedInPlace(ContractID, version: SchemaVersion)
        case droppedFields(ContractID, from: SchemaVersion, to: SchemaVersion, fields: [String])
        case refusedLossyMigration(ContractID, from: SchemaVersion, to: SchemaVersion, fields: [String])
        case refusedSunsetTarget(ContractID, version: SchemaVersion)
        case refusedNoPath(ContractID, from: SchemaVersion, to: SchemaVersion)
        case sourceRejected(ContractID, version: SchemaVersion, violations: Int)
        case postconditionFailed(ContractID, version: SchemaVersion, violations: Int)
        case stepThrew(ContractID, from: SchemaVersion, to: SchemaVersion)
        case negotiated(ContractID, producer: SchemaVersion, consumer: SchemaVersion, outcome: String)
        case negotiationRefused(ContractID, reason: NegotiationRefusal)
        case compatibilityChecked(ContractID, from: SchemaVersion, to: SchemaVersion, breaking: Int)
    }

    /// Position in the trail, starting at 1.
    public let sequence: Int

    /// What happened.
    public let kind: Kind

    public init(sequence: Int, kind: Kind) {
        self.sequence = sequence
        self.kind = kind
    }

    public var description: String {
        "#\(sequence) \(String(describing: kind))"
    }
}
