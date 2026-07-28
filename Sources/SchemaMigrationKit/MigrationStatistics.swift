/// A running tally of what a registry has been asked to do.
public struct MigrationStatistics: Sendable, Hashable, CustomStringConvertible {

    public let contracts: Int
    public let steps: Int
    public let migrations: Int
    public let inPlaceReuses: Int
    public let refusals: Int
    public let fieldsDropped: Int

    public init(
        contracts: Int,
        steps: Int,
        migrations: Int,
        inPlaceReuses: Int,
        refusals: Int,
        fieldsDropped: Int
    ) {
        self.contracts = contracts
        self.steps = steps
        self.migrations = migrations
        self.inPlaceReuses = inPlaceReuses
        self.refusals = refusals
        self.fieldsDropped = fieldsDropped
    }

    public var description: String {
        "contracts \(contracts), steps \(steps), migrations \(migrations), "
            + "reused \(inPlaceReuses), refusals \(refusals), fields dropped \(fieldsDropped)"
    }
}
