/// A single way a payload fails to satisfy a schema.
public enum SchemaViolation: Sendable, Hashable, CustomStringConvertible {

    /// A field the schema marks required is absent.
    case missingRequiredField(String)

    /// A field is present but carries the wrong type.
    case typeMismatch(field: String, expected: FieldType, actual: FieldType)

    /// The name of the field this violation is about.
    public var field: String {
        switch self {
        case .missingRequiredField(let name): return name
        case .typeMismatch(let field, _, _): return field
        }
    }

    public var description: String {
        switch self {
        case .missingRequiredField(let name):
            return "missing required field '\(name)'"
        case .typeMismatch(let field, let expected, let actual):
            return "field '\(field)' expected \(expected) but found \(actual)"
        }
    }
}
