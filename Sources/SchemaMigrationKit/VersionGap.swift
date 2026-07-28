/// An adjacent version pair with no registered step to cross it.
public struct VersionGap: Sendable, Hashable, CustomStringConvertible {

    public let from: SchemaVersion
    public let to: SchemaVersion

    public init(from: SchemaVersion, to: SchemaVersion) {
        self.from = from
        self.to = to
    }

    public var description: String {
        "\(from) -> \(to)"
    }
}
