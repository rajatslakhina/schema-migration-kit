/// What a producer and a consumer agreed on.
public enum NegotiationOutcome: Sendable {

    /// Both sides already speak the same version.
    case exact(SchemaVersion)

    /// They differ, but a lossless path bridges them.
    case migrate(MigrationPath)

    /// They cannot be bridged, and this is why.
    case unsupported(NegotiationRefusal)
}

extension NegotiationOutcome: CustomStringConvertible {
    public var description: String {
        switch self {
        case .exact(let version): return "exact \(version)"
        case .migrate(let path): return "migrate \(path)"
        case .unsupported(let refusal): return "unsupported: \(refusal)"
        }
    }
}
