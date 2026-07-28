/// Whether moving between two versions of a schema is safe for a consumer that
/// was written against the older one.
public enum CompatibilityVerdict: Sendable, Hashable, CustomStringConvertible {

    /// Every change is additive or optional. Old consumers keep working.
    case compatible

    /// At least one change would break an old consumer.
    case breaking([BreakingChange])

    /// `true` when at least one breaking change was found.
    public var isBreaking: Bool {
        switch self {
        case .compatible: return false
        case .breaking: return true
        }
    }

    /// The breaking changes, empty when compatible.
    public var changes: [BreakingChange] {
        switch self {
        case .compatible: return []
        case .breaking(let changes): return changes
        }
    }

    public var description: String {
        switch self {
        case .compatible:
            return "compatible"
        case .breaking(let changes):
            return "breaking (\(changes.map(\.description).joined(separator: "; ")))"
        }
    }
}
