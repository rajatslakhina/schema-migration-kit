/// An audit trail that keeps everything in memory.
public actor InMemoryMigrationEventRecorder: MigrationEventRecording {

    private var storage: [MigrationEvent] = []

    public init() {}

    public func record(_ event: MigrationEvent) {
        storage.append(event)
    }

    public func recorded() -> [MigrationEvent] {
        storage
    }

    /// How many events have been recorded.
    public func count() -> Int {
        storage.count
    }
}
