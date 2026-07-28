/// A payload that made it all the way to the target version, plus what it cost.
public struct MigrationResult: Sendable {

    /// The migrated payload. It has already been validated against the target
    /// version's schema — the registry does not hand back a payload it has not
    /// checked.
    public let payload: [String: FieldValue]

    /// The path that produced it.
    public let path: MigrationPath

    /// Fields discarded along the way, sorted. Empty unless the caller opted
    /// into a lossy migration.
    public let droppedFields: [String]

    public init(payload: [String: FieldValue], path: MigrationPath, droppedFields: [String]) {
        self.payload = payload
        self.path = path
        self.droppedFields = droppedFields
    }

    /// How many hops actually ran. Zero for an in-place reuse.
    public var appliedSteps: Int {
        path.stepCount
    }

    /// Which way the migration ran.
    public var direction: MigrationDirection {
        path.direction
    }
}
