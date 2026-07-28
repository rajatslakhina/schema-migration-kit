/// A JSON-shaped value carried by a contract payload.
///
/// The package owns its own value vocabulary rather than importing one, so it
/// has no compile-time dependency on any sibling package. A caller bridging
/// from `StructuredOutputKit`'s `JSONValue` writes one adapter and is done.
public enum FieldValue: Sendable, Hashable {
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)
    case array([FieldValue])
    case object([String: FieldValue])
    case null

    /// The declared type this value satisfies.
    public var kind: FieldType {
        switch self {
        case .string: return .string
        case .integer: return .integer
        case .double: return .double
        case .boolean: return .boolean
        case .array: return .array
        case .object: return .object
        case .null: return .null
        }
    }
}

extension FieldValue: CustomStringConvertible {

    /// A stable, key-sorted rendering.
    ///
    /// Sorted keys are not cosmetic. They make a payload's printed form agree
    /// with its canonical form, so demo output and audit trails are byte-stable
    /// across runs and across machines.
    public var description: String {
        switch self {
        case .string(let value): return "\"\(value)\""
        case .integer(let value): return "\(value)"
        case .double(let value): return "\(value)"
        case .boolean(let value): return value ? "true" : "false"
        case .array(let values): return "[\(values.map(\.description).joined(separator: ", "))]"
        case .object(let fields): return "{\(FieldValue.render(fields))}"
        case .null: return "null"
        }
    }

    /// Renders an object body with its keys in sorted order.
    public static func render(_ fields: [String: FieldValue]) -> String {
        fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: ", ")
    }
}
