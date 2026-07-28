/// Why a producer and a consumer could not be reconciled.
public enum NegotiationRefusal: Sendable, Hashable, CustomStringConvertible {

    /// The producer claims a version the registry has never heard of.
    case producerVersionUnknown(SchemaVersion)

    /// The consumer wants a version the registry has never heard of.
    case consumerVersionUnknown(SchemaVersion)

    /// Both versions are known, but no chain of steps connects them.
    case noMigrationPath(from: SchemaVersion, to: SchemaVersion)

    /// The consumer's version is past its sunset.
    case versionSunset(SchemaVersion, status: VersionStatus)

    /// A path exists but would silently discard fields, so it is not offered
    /// as an automatic answer.
    case migrationIsLossy(from: SchemaVersion, to: SchemaVersion, drops: [String])

    public var description: String {
        switch self {
        case .producerVersionUnknown(let version):
            return "producer version \(version) is not registered"
        case .consumerVersionUnknown(let version):
            return "consumer version \(version) is not registered"
        case .noMigrationPath(let from, let to):
            return "no migration path \(from) -> \(to)"
        case .versionSunset(let version, let status):
            return "consumer version \(version) is \(status)"
        case .migrationIsLossy(let from, let to, let drops):
            return "\(from) -> \(to) would drop \(drops.sorted().joined(separator: ", "))"
        }
    }
}
