/// The actor that owns every contract, every version, and every step between
/// them.
///
/// Registration, planning, and execution all live behind one actor on purpose.
/// A step lookup that crossed an `await` boundary could observe a registry
/// mid-registration and plan a path that no longer exists by the time it runs.
public actor SchemaRegistry {

    /// A single hop, keyed by its endpoints.
    struct StepKey: Hashable {
        let from: SchemaVersion
        let to: SchemaVersion
    }

    /// Everything the registry knows about one contract.
    struct StoredContract {
        var order: [SchemaVersion]
        var versions: [SchemaVersion: ContractVersionDefinition]
        var steps: [StepKey: any PayloadMigrating]
    }

    var contracts: [ContractID: StoredContract] = [:]
    var sequence = 0
    var migrationCount = 0
    var reuseCount = 0
    var refusalCount = 0
    var droppedFieldCount = 0

    let recorder: (any MigrationEventRecording)?

    /// Creates a registry, optionally wired to an audit trail.
    public init(recorder: (any MigrationEventRecording)? = nil) {
        self.recorder = recorder
    }

    // MARK: - Registration

    /// Registers a contract and all of its versions at once.
    public func register(_ contract: ContractDefinition) async throws {
        guard !contract.id.isBlank else {
            throw MigrationError.blankContractID
        }
        guard contracts[contract.id] == nil else {
            throw MigrationError.duplicateContract(contract.id)
        }
        let ordered = contract.ordered()
        guard !ordered.isEmpty else {
            throw MigrationError.contractHasNoVersions(contract.id)
        }
        var versions: [SchemaVersion: ContractVersionDefinition] = [:]
        for definition in ordered {
            guard versions[definition.version] == nil else {
                throw MigrationError.duplicateVersion(contract: contract.id, version: definition.version)
            }
            versions[definition.version] = definition
        }
        contracts[contract.id] = StoredContract(
            order: ordered.map(\.version),
            versions: versions,
            steps: [:]
        )
        await emit(.contractRegistered(contract.id, versions: ordered.count))
    }

    /// Registers one hop.
    ///
    /// A step whose endpoints are not adjacent is refused. A shortcut edge
    /// would let a v1 payload reach v3 without ever being checked against v2,
    /// which is exactly the silent drift this package exists to prevent.
    public func registerStep(_ step: any PayloadMigrating, for id: ContractID) async throws {
        var stored = try contract(id)
        try require(stored, has: step.from, in: id)
        try require(stored, has: step.to, in: id)
        guard isAdjacent(step.from, step.to, in: stored) else {
            throw MigrationError.stepNotAdjacent(contract: id, from: step.from, to: step.to)
        }
        let key = StepKey(from: step.from, to: step.to)
        guard stored.steps[key] == nil else {
            throw MigrationError.duplicateStep(contract: id, from: step.from, to: step.to)
        }
        stored.steps[key] = step
        contracts[id] = stored
        await emit(.stepRegistered(id, from: step.from, to: step.to))
    }

    /// Attaches a deprecation window to one version.
    public func deprecate(
        _ id: ContractID,
        version: SchemaVersion,
        notice: DeprecationNotice
    ) async throws {
        var stored = try contract(id)
        let existing = try definition(id, version)
        stored.versions[version] = existing.deprecated(by: notice)
        contracts[id] = stored
        await emit(.deprecated(id, version: version, at: notice.deprecatedAt))
    }

    // MARK: - Lookup

    /// The schema one version promises.
    public func schema(of id: ContractID, version: SchemaVersion) throws -> ContractSchema {
        try definition(id, version).schema
    }

    /// The lifecycle state of one version at `tick`.
    public func status(of id: ContractID, version: SchemaVersion, at tick: Int) throws -> VersionStatus {
        try definition(id, version).status(at: tick)
    }

    /// The registered versions of a contract, ascending.
    public func versions(of id: ContractID) throws -> [SchemaVersion] {
        try contract(id).order
    }

    /// A running tally of what this registry has been asked to do.
    public func statistics() -> MigrationStatistics {
        MigrationStatistics(
            contracts: contracts.count,
            steps: contracts.values.reduce(0) { $0 + $1.steps.count },
            migrations: migrationCount,
            inPlaceReuses: reuseCount,
            refusals: refusalCount,
            fieldsDropped: droppedFieldCount
        )
    }

    // MARK: - Internals

    func contract(_ id: ContractID) throws -> StoredContract {
        guard let stored = contracts[id] else {
            throw MigrationError.unknownContract(id)
        }
        return stored
    }

    func definition(_ id: ContractID, _ version: SchemaVersion) throws -> ContractVersionDefinition {
        let stored = try contract(id)
        guard let found = stored.versions[version] else {
            throw MigrationError.unknownVersion(contract: id, version: version)
        }
        return found
    }

    func require(_ stored: StoredContract, has version: SchemaVersion, in id: ContractID) throws {
        guard stored.versions[version] != nil else {
            throw MigrationError.unknownVersion(contract: id, version: version)
        }
    }

    /// How many registered versions sort below `version`.
    ///
    /// Used instead of `firstIndex(of:)` so there is no "version not found"
    /// branch to leave untested — callers have already proved it is registered.
    func position(of version: SchemaVersion, in stored: StoredContract) -> Int {
        stored.order.reduce(into: 0) { count, candidate in
            if candidate < version {
                count += 1
            }
        }
    }

    func isAdjacent(_ lhs: SchemaVersion, _ rhs: SchemaVersion, in stored: StoredContract) -> Bool {
        abs(position(of: lhs, in: stored) - position(of: rhs, in: stored)) == 1
    }

    func emit(_ kind: MigrationEvent.Kind) async {
        sequence += 1
        await recorder?.record(MigrationEvent(sequence: sequence, kind: kind))
    }
}
