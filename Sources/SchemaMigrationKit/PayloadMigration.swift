/// A closure-backed migration step, for the common case where a hop is a few
/// lines of field surgery and does not deserve its own type.
public struct PayloadMigration: PayloadMigrating {

    public let from: SchemaVersion
    public let to: SchemaVersion
    public let loss: LossPolicy

    private let body: @Sendable ([String: FieldValue]) throws -> [String: FieldValue]

    public init(
        from: SchemaVersion,
        to: SchemaVersion,
        loss: LossPolicy = .lossless,
        _ body: @escaping @Sendable ([String: FieldValue]) throws -> [String: FieldValue]
    ) {
        self.from = from
        self.to = to
        self.loss = loss
        self.body = body
    }

    public func migrate(_ payload: [String: FieldValue]) throws -> [String: FieldValue] {
        try body(payload)
    }
}
