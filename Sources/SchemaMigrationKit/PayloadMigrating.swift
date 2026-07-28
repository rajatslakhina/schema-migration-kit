/// One hop between two adjacent versions of a contract.
///
/// This is the seam the package is built around: the registry owns ordering,
/// validation, and refusal, while a step owns nothing but the field surgery for
/// its own hop.
public protocol PayloadMigrating: Sendable {

    /// The version a payload must already satisfy to enter this step.
    var from: SchemaVersion { get }

    /// The version this step promises to produce.
    var to: SchemaVersion { get }

    /// What this step admits it discards.
    var loss: LossPolicy { get }

    /// Rewrites the payload. Throwing here is a legitimate outcome — the
    /// registry reports it as a failed step rather than letting it escape raw.
    func migrate(_ payload: [String: FieldValue]) throws -> [String: FieldValue]
}

extension PayloadMigrating {

    /// Which way this step runs, derived from its endpoints.
    public var direction: MigrationDirection {
        from < to ? .upgrade : .downgrade
    }

    /// A short label used in audit trails and error messages.
    public var label: String {
        "\(from) -> \(to)"
    }
}
