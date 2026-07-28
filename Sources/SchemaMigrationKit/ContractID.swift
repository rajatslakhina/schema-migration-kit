/// The name of a versioned contract — a structured-output shape, a tool's
/// argument object, or any other payload whose fields change over time.
public struct ContractID: Sendable, Hashable, CustomStringConvertible {

    /// The underlying name.
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    /// `true` when the name is empty or nothing but whitespace.
    ///
    /// A blank name is refused at registration rather than accepted as a
    /// catch-all, for the same reason `IdempotencyKit` refuses a blank key: a
    /// wildcard contract collides with every other one.
    public var isBlank: Bool {
        rawValue.allSatisfy(\.isWhitespace)
    }

    public var description: String {
        rawValue
    }
}

extension ContractID: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}
