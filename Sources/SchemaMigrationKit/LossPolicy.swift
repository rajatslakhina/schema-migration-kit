/// What a migration step admits it throws away.
///
/// Loss is declared by the step's author, not inferred from the schemas. A diff
/// can tell you a field is gone; only the author can tell you whether it was
/// folded into another field or genuinely discarded.
public enum LossPolicy: Sendable, Hashable, CustomStringConvertible {

    /// Nothing is discarded.
    case lossless

    /// The named fields do not survive this step.
    case lossy(drops: [String])

    /// The fields this policy discards, sorted. Empty when lossless.
    public var droppedFields: [String] {
        switch self {
        case .lossless: return []
        case .lossy(let drops): return drops.sorted()
        }
    }

    public var description: String {
        switch self {
        case .lossless: return "lossless"
        case .lossy(let drops): return "lossy(\(drops.sorted().joined(separator: ", ")))"
        }
    }
}
