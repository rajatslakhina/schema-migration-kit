/// The field list one version of a contract declares.
public struct ContractSchema: Sendable, Hashable {

    /// The declared fields, in declaration order.
    public let fields: [FieldDefinition]

    public init(_ fields: [FieldDefinition]) {
        self.fields = fields
    }

    /// The definition of a named field, if the schema declares one.
    public func definition(named name: String) -> FieldDefinition? {
        fields.first { $0.name == name }
    }

    /// The declared field names, sorted.
    public func names() -> [String] {
        fields.map(\.name).sorted()
    }

    /// Every way `payload` fails this schema, sorted by field name so the
    /// result is stable.
    ///
    /// Fields the schema does not declare are ignored rather than reported.
    /// That is deliberate: the must-ignore-unknown rule is what lets a v2
    /// producer talk to a v1 consumer at all, and a migration layer that
    /// rejected unknown fields would make every additive change breaking.
    public func validate(_ payload: [String: FieldValue]) -> [SchemaViolation] {
        var violations: [SchemaViolation] = []
        for field in fields {
            guard let value = payload[field.name] else {
                if field.isRequired {
                    violations.append(.missingRequiredField(field.name))
                }
                continue
            }
            if value.kind != field.type {
                violations.append(
                    .typeMismatch(field: field.name, expected: field.type, actual: value.kind)
                )
            }
        }
        return violations.sorted { $0.field < $1.field }
    }

    /// Classifies the move from this schema to `newer`.
    public func compatibility(to newer: ContractSchema) -> CompatibilityVerdict {
        var changes = carriedForwardChanges(to: newer)
        changes.append(contentsOf: newer.introducedRequirements(comparedTo: self))
        return changes.isEmpty ? .compatible : .breaking(changes)
    }

    /// Fields this schema declares that `newer` drops, retypes, or tightens.
    private func carriedForwardChanges(to newer: ContractSchema) -> [BreakingChange] {
        fields.compactMap { old in
            guard let match = newer.definition(named: old.name) else {
                return .fieldRemoved(old.name)
            }
            if match.type != old.type {
                return .fieldTypeChanged(field: old.name, from: old.type, to: match.type)
            }
            if match.isRequired && !old.isRequired {
                return .optionalFieldMadeRequired(old.name)
            }
            return nil
        }
    }

    /// Fields this schema requires that `older` never declared at all.
    private func introducedRequirements(comparedTo older: ContractSchema) -> [BreakingChange] {
        fields
            .filter { $0.isRequired && older.definition(named: $0.name) == nil }
            .map { .requiredFieldAdded($0.name) }
    }
}
