/// Which way a migration runs.
public enum MigrationDirection: Sendable, Hashable, CustomStringConvertible {

    /// Older payload, newer schema.
    case upgrade

    /// Newer payload, older schema — the case that serves a client which has
    /// not shipped yet.
    case downgrade

    public var description: String {
        switch self {
        case .upgrade: return "upgrade"
        case .downgrade: return "downgrade"
        }
    }
}
