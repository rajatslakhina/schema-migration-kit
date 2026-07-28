/// Which hops of a contract are actually crossable.
///
/// Coverage is the answer to a question a dictionary of migration closures
/// cannot answer: *before* production traffic arrives, is there a step for
/// every hop, in both directions?
public struct MigrationCoverage: Sendable, Hashable, CustomStringConvertible {

    public let contract: ContractID
    public let versions: [SchemaVersion]
    public let upgradeGaps: [VersionGap]
    public let downgradeGaps: [VersionGap]

    public init(
        contract: ContractID,
        versions: [SchemaVersion],
        upgradeGaps: [VersionGap],
        downgradeGaps: [VersionGap]
    ) {
        self.contract = contract
        self.versions = versions
        self.upgradeGaps = upgradeGaps
        self.downgradeGaps = downgradeGaps
    }

    /// `true` when every adjacent pair has a forward step.
    public var canUpgradeThroughout: Bool {
        upgradeGaps.isEmpty
    }

    /// `true` when every adjacent pair has a backward step.
    public var canDowngradeThroughout: Bool {
        downgradeGaps.isEmpty
    }

    public var description: String {
        let chain = versions.map(\.description).joined(separator: " -> ")
        return "\(contract) [\(chain)] upgrade gaps \(upgradeGaps.count), downgrade gaps \(downgradeGaps.count)"
    }
}
