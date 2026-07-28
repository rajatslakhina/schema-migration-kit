/// Where a version sits in its lifecycle at a given tick.
public enum VersionStatus: Sendable, Hashable, CustomStringConvertible {

    /// Fully supported.
    case active

    /// Still accepted, but callers are being asked to move off it.
    case deprecated(since: Int)

    /// No longer accepted as a migration target.
    case sunset(since: Int)

    /// `true` once the version has passed its sunset tick.
    public var isSunset: Bool {
        switch self {
        case .active, .deprecated: return false
        case .sunset: return true
        }
    }

    public var description: String {
        switch self {
        case .active: return "active"
        case .deprecated(let since): return "deprecated since tick \(since)"
        case .sunset(let since): return "sunset since tick \(since)"
        }
    }
}
