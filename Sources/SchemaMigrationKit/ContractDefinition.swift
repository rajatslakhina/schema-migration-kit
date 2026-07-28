/// A named contract and every version of it the application knows about.
///
/// All versions are declared in one call rather than added incrementally. That
/// is not an accident of API taste: migration steps are checked for adjacency
/// at registration, and inserting a version afterwards would silently invalidate
/// the adjacency of steps already accepted.
public struct ContractDefinition: Sendable, Hashable {

    public let id: ContractID
    public let versions: [ContractVersionDefinition]

    public init(id: ContractID, versions: [ContractVersionDefinition]) {
        self.id = id
        self.versions = versions
    }

    /// The declared versions in ascending order.
    public func ordered() -> [ContractVersionDefinition] {
        versions.sorted { $0.version < $1.version }
    }
}
