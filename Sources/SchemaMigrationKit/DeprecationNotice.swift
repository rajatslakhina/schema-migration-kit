/// The deprecation window attached to one version of a contract.
///
/// Both ticks are caller-supplied logical time. The package never reads a
/// clock, which is what lets a test assert the exact tick a version stops being
/// a legal migration target without sleeping.
public struct DeprecationNotice: Sendable, Hashable {

    /// The tick from which the version counts as deprecated.
    public let deprecatedAt: Int

    /// The tick from which the version stops being an acceptable target, if a
    /// sunset was scheduled at all.
    public let sunsetAt: Int?

    /// Creates a notice, clamping a sunset that would land before the
    /// deprecation that announced it.
    public init(deprecatedAt: Int, sunsetAt: Int? = nil) {
        self.deprecatedAt = deprecatedAt
        self.sunsetAt = sunsetAt.map { max(deprecatedAt, $0) }
    }

    /// The lifecycle state this notice implies at `tick`.
    public func status(at tick: Int) -> VersionStatus {
        if let sunsetAt, tick >= sunsetAt {
            return .sunset(since: sunsetAt)
        }
        if tick >= deprecatedAt {
            return .deprecated(since: deprecatedAt)
        }
        return .active
    }
}
