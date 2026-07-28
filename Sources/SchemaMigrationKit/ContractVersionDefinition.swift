/// One version of a contract: the version number, the shape it promises, and
/// its deprecation window if it has one.
public struct ContractVersionDefinition: Sendable, Hashable {

    public let version: SchemaVersion
    public let schema: ContractSchema
    public let deprecation: DeprecationNotice?

    public init(
        version: SchemaVersion,
        schema: ContractSchema,
        deprecation: DeprecationNotice? = nil
    ) {
        self.version = version
        self.schema = schema
        self.deprecation = deprecation
    }

    /// The lifecycle state of this version at `tick`.
    public func status(at tick: Int) -> VersionStatus {
        deprecation?.status(at: tick) ?? .active
    }

    /// A copy of this version carrying `notice`.
    public func deprecated(by notice: DeprecationNotice) -> ContractVersionDefinition {
        ContractVersionDefinition(version: version, schema: schema, deprecation: notice)
    }
}
