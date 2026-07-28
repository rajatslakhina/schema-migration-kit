/// A single, totally ordered schema version for a contract.
///
/// Versions are plain integers on purpose. Schema evolution composes one hop at
/// a time, and a total order is what makes "walk from v1 to v3" deterministic
/// rather than a graph search whose answer depends on registration order.
public struct SchemaVersion: Sendable, Hashable, Comparable, CustomStringConvertible {

    /// The version number. Always at least `1`.
    public let number: Int

    /// Creates a version, clamping anything below `1` up to `1`.
    ///
    /// Clamping rather than throwing matches the rest of the ecosystem: bounds
    /// correct a caller's mistake, they do not turn it into a failure path.
    public init(_ number: Int) {
        self.number = max(1, number)
    }

    public static func < (lhs: SchemaVersion, rhs: SchemaVersion) -> Bool {
        lhs.number < rhs.number
    }

    public var description: String {
        "v\(number)"
    }
}

extension SchemaVersion: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(value)
    }
}
