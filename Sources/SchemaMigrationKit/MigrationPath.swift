/// The ordered hops that carry a payload from one version to another.
///
/// A path is always a walk over adjacent registered versions. There are no
/// shortcut edges, so a v1 payload bound for v3 is checked against v2 on the
/// way through rather than jumping past it.
public struct MigrationPath: Sendable {

    public let contract: ContractID
    public let from: SchemaVersion
    public let to: SchemaVersion
    public let steps: [any PayloadMigrating]

    public init(
        contract: ContractID,
        from: SchemaVersion,
        to: SchemaVersion,
        steps: [any PayloadMigrating]
    ) {
        self.contract = contract
        self.from = from
        self.to = to
        self.steps = steps
    }

    /// `true` when source and target are the same version and nothing runs.
    public var isIdentity: Bool {
        steps.isEmpty
    }

    /// How many hops this path runs.
    public var stepCount: Int {
        steps.count
    }

    /// Which way the path runs. An identity path counts as an upgrade.
    public var direction: MigrationDirection {
        from <= to ? .upgrade : .downgrade
    }

    /// Every field any step on this path admits it discards, deduplicated and
    /// sorted.
    public var droppedFields: [String] {
        Set(steps.flatMap(\.loss.droppedFields)).sorted()
    }
}

extension MigrationPath: CustomStringConvertible {
    public var description: String {
        "\(from) -> \(to) (\(stepCount) step\(stepCount == 1 ? "" : "s"))"
    }
}
