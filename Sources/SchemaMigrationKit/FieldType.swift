/// The declared type of a single field in a contract schema.
public enum FieldType: String, Sendable, Hashable, CustomStringConvertible {
    case string
    case integer
    case double
    case boolean
    case array
    case object
    case null

    public var description: String {
        rawValue
    }
}
