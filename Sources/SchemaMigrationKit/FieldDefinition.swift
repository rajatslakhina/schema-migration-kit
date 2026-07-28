/// One field in a contract schema: its name, its type, and whether a payload
/// has to carry it.
public struct FieldDefinition: Sendable, Hashable {

    public let name: String
    public let type: FieldType
    public let isRequired: Bool

    public init(name: String, type: FieldType, isRequired: Bool) {
        self.name = name
        self.type = type
        self.isRequired = isRequired
    }

    /// A field a payload must carry.
    public static func required(_ name: String, _ type: FieldType) -> FieldDefinition {
        FieldDefinition(name: name, type: type, isRequired: true)
    }

    /// A field a payload may omit.
    public static func optional(_ name: String, _ type: FieldType) -> FieldDefinition {
        FieldDefinition(name: name, type: type, isRequired: false)
    }
}
