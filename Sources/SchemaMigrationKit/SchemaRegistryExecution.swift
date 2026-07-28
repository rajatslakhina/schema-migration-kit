extension SchemaRegistry {

    // MARK: - Planning

    /// The hops that would carry a payload from `from` to `to`.
    ///
    /// Paths walk adjacent registered versions in order. A missing hop is a
    /// refusal, not a silent skip.
    public func plan(_ id: ContractID, from: SchemaVersion, to: SchemaVersion) throws -> MigrationPath {
        let stored = try contract(id)
        try require(stored, has: from, in: id)
        try require(stored, has: to, in: id)
        var steps: [any PayloadMigrating] = []
        for hop in hops(stored, from: from, to: to) {
            guard let step = stored.steps[hop] else {
                throw MigrationError.noMigrationPath(contract: id, from: from, to: to)
            }
            steps.append(step)
        }
        return MigrationPath(contract: id, from: from, to: to, steps: steps)
    }

    /// Which adjacent hops are crossable, in both directions.
    public func coverage(of id: ContractID) throws -> MigrationCoverage {
        let stored = try contract(id)
        var upgradeGaps: [VersionGap] = []
        var downgradeGaps: [VersionGap] = []
        for (index, version) in stored.order.enumerated().dropLast() {
            let next = stored.order[index + 1]
            if stored.steps[StepKey(from: version, to: next)] == nil {
                upgradeGaps.append(VersionGap(from: version, to: next))
            }
            if stored.steps[StepKey(from: next, to: version)] == nil {
                downgradeGaps.append(VersionGap(from: next, to: version))
            }
        }
        return MigrationCoverage(
            contract: id,
            versions: stored.order,
            upgradeGaps: upgradeGaps,
            downgradeGaps: downgradeGaps
        )
    }

    /// Classifies the move between two versions of the same contract.
    public func compatibility(
        of id: ContractID,
        from: SchemaVersion,
        to: SchemaVersion
    ) async throws -> CompatibilityVerdict {
        let older = try definition(id, from).schema
        let newer = try definition(id, to).schema
        let verdict = older.compatibility(to: newer)
        await emit(.compatibilityChecked(id, from: from, to: to, breaking: verdict.changes.count))
        return verdict
    }

    // MARK: - Execution

    /// Migrates a payload, validating it before it starts and after every hop.
    ///
    /// - Parameter allowingLoss: a path whose steps declare dropped fields is
    ///   refused unless the caller opts in. Serving a stale client half a
    ///   payload it cannot tell is incomplete is worse than refusing.
    public func migrate(
        _ payload: [String: FieldValue],
        of id: ContractID,
        from: SchemaVersion,
        to: SchemaVersion,
        at tick: Int = 0,
        allowingLoss: Bool = false
    ) async throws -> MigrationResult {
        let source = try definition(id, from)
        let target = try definition(id, to)
        try await refuseSunsetTarget(target, id: id, tick: tick)
        try await refuseInvalidSource(source, id: id, payload: payload)
        let path = try await planOrRefuse(id, from: from, to: to)
        guard !path.isIdentity else {
            return await reuseInPlace(payload, id: id, version: from, path: path)
        }
        let drops = path.droppedFields
        try await refuseUnwantedLoss(drops, id: id, from: from, to: to, allowingLoss: allowingLoss)
        let migrated = try await apply(path, to: payload, id: id)
        migrationCount += 1
        droppedFieldCount += drops.count
        await emit(.migrated(id, from: from, to: to, steps: path.stepCount))
        if !drops.isEmpty {
            await emit(.droppedFields(id, from: from, to: to, fields: drops))
        }
        return MigrationResult(payload: migrated, path: path, droppedFields: drops)
    }

    /// Reconciles the version a producer emits with the version a consumer
    /// wants.
    public func negotiate(
        _ id: ContractID,
        producerVersion: SchemaVersion,
        consumerVersion: SchemaVersion,
        at tick: Int = 0
    ) async throws -> NegotiationOutcome {
        let stored = try contract(id)
        guard stored.versions[producerVersion] != nil else {
            return await refuse(id, .producerVersionUnknown(producerVersion))
        }
        guard let consumer = stored.versions[consumerVersion] else {
            return await refuse(id, .consumerVersionUnknown(consumerVersion))
        }
        guard producerVersion != consumerVersion else {
            await emit(.negotiated(id, producer: producerVersion, consumer: consumerVersion, outcome: "exact"))
            return .exact(producerVersion)
        }
        let status = consumer.status(at: tick)
        guard !status.isSunset else {
            return await refuse(id, .versionSunset(consumerVersion, status: status))
        }
        guard let path = try? plan(id, from: producerVersion, to: consumerVersion) else {
            return await refuse(id, .noMigrationPath(from: producerVersion, to: consumerVersion))
        }
        let drops = path.droppedFields
        guard drops.isEmpty else {
            return await refuse(id, .migrationIsLossy(from: producerVersion, to: consumerVersion, drops: drops))
        }
        await emit(.negotiated(id, producer: producerVersion, consumer: consumerVersion, outcome: "migrate"))
        return .migrate(path)
    }

    // MARK: - Internals

    /// The adjacent hops between two versions, in travel order.
    func hops(_ stored: StoredContract, from: SchemaVersion, to: SchemaVersion) -> [StepKey] {
        let lower = min(from, to)
        let upper = max(from, to)
        let inRange = stored.order.filter { $0 >= lower && $0 <= upper }
        let ordered = from < to ? inRange : Array(inRange.reversed())
        return zip(ordered, ordered.dropFirst()).map { StepKey(from: $0, to: $1) }
    }

    func refuseSunsetTarget(_ target: ContractVersionDefinition, id: ContractID, tick: Int) async throws {
        let status = target.status(at: tick)
        guard status.isSunset else { return }
        refusalCount += 1
        await emit(.refusedSunsetTarget(id, version: target.version))
        throw MigrationError.versionSunset(contract: id, version: target.version, status: status)
    }

    func refuseInvalidSource(
        _ source: ContractVersionDefinition,
        id: ContractID,
        payload: [String: FieldValue]
    ) async throws {
        let violations = source.schema.validate(payload)
        guard !violations.isEmpty else { return }
        refusalCount += 1
        await emit(.sourceRejected(id, version: source.version, violations: violations.count))
        throw MigrationError.sourcePayloadInvalid(
            contract: id,
            version: source.version,
            violations: violations
        )
    }

    func refuseUnwantedLoss(
        _ drops: [String],
        id: ContractID,
        from: SchemaVersion,
        to: SchemaVersion,
        allowingLoss: Bool
    ) async throws {
        guard !drops.isEmpty, !allowingLoss else { return }
        refusalCount += 1
        await emit(.refusedLossyMigration(id, from: from, to: to, fields: drops))
        throw MigrationError.lossyMigrationRefused(contract: id, from: from, to: to, drops: drops)
    }

    func planOrRefuse(_ id: ContractID, from: SchemaVersion, to: SchemaVersion) async throws -> MigrationPath {
        do {
            return try plan(id, from: from, to: to)
        } catch {
            refusalCount += 1
            await emit(.refusedNoPath(id, from: from, to: to))
            throw error
        }
    }

    func reuseInPlace(
        _ payload: [String: FieldValue],
        id: ContractID,
        version: SchemaVersion,
        path: MigrationPath
    ) async -> MigrationResult {
        reuseCount += 1
        await emit(.reusedInPlace(id, version: version))
        return MigrationResult(payload: payload, path: path, droppedFields: [])
    }

    func apply(
        _ path: MigrationPath,
        to payload: [String: FieldValue],
        id: ContractID
    ) async throws -> [String: FieldValue] {
        var current = payload
        for step in path.steps {
            current = try await run(step, on: current, id: id)
            try await verify(current, after: step, id: id)
        }
        return current
    }

    func run(
        _ step: any PayloadMigrating,
        on payload: [String: FieldValue],
        id: ContractID
    ) async throws -> [String: FieldValue] {
        do {
            return try step.migrate(payload)
        } catch {
            refusalCount += 1
            await emit(.stepThrew(id, from: step.from, to: step.to))
            throw MigrationError.stepFailed(
                contract: id,
                from: step.from,
                to: step.to,
                message: "\(error)"
            )
        }
    }

    /// Checks a hop's output against the schema that hop promised.
    ///
    /// This is the difference between a migration layer and a dictionary of
    /// closures: a step that says it produced v2 has to actually produce v2,
    /// and the failure names the step rather than surfacing three hops later as
    /// a decode error.
    func verify(_ payload: [String: FieldValue], after step: any PayloadMigrating, id: ContractID) async throws {
        let target = try definition(id, step.to)
        let violations = target.schema.validate(payload)
        guard !violations.isEmpty else { return }
        refusalCount += 1
        await emit(.postconditionFailed(id, version: step.to, violations: violations.count))
        throw MigrationError.postconditionViolated(
            contract: id,
            step: step.label,
            version: step.to,
            violations: violations
        )
    }

    func refuse(_ id: ContractID, _ reason: NegotiationRefusal) async -> NegotiationOutcome {
        refusalCount += 1
        await emit(.negotiationRefused(id, reason: reason))
        return .unsupported(reason)
    }
}
