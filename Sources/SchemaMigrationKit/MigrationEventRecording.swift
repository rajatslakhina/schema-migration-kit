/// Where a registry sends its audit trail.
///
/// A seam rather than a concrete log, so an application can forward events to
/// `TraceKit`, to its own observability pipeline, or nowhere at all.
public protocol MigrationEventRecording: Sendable {

    /// Appends one event.
    func record(_ event: MigrationEvent) async

    /// Everything recorded so far, oldest first.
    func recorded() async -> [MigrationEvent]
}
