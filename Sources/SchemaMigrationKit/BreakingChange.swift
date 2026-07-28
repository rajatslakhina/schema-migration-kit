/// A single reason one version of a schema is not a drop-in replacement for
/// another.
public enum BreakingChange: Sendable, Hashable, CustomStringConvertible {

    /// A field present in the older version is gone from the newer one.
    case fieldRemoved(String)

    /// A field kept its name but changed type.
    case fieldTypeChanged(field: String, from: FieldType, to: FieldType)

    /// The newer version introduces a field it also demands.
    case requiredFieldAdded(String)

    /// A field that used to be optional is now mandatory.
    case optionalFieldMadeRequired(String)

    public var description: String {
        switch self {
        case .fieldRemoved(let name):
            return "field '\(name)' removed"
        case .fieldTypeChanged(let field, let from, let to):
            return "field '\(field)' changed type \(from) -> \(to)"
        case .requiredFieldAdded(let name):
            return "required field '\(name)' added"
        case .optionalFieldMadeRequired(let name):
            return "field '\(name)' became required"
        }
    }
}
