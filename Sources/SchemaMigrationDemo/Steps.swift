import SchemaMigrationKit

/// The demo's migration steps.
enum Steps {

    /// Adds the optional field v2 introduced.
    static func alertUpgradeToV2() -> PayloadMigration {
        PayloadMigration(from: 1, to: 2) { payload in
            var next = payload
            next["confidence"] = .double(0.5)
            return next
        }
    }

    /// Turns a numeric severity into a band and stamps the issue tick.
    static func alertUpgradeToV3(issuedAtTick: Int) -> PayloadMigration {
        PayloadMigration(from: 2, to: 3) { payload in
            var next = payload
            if case .integer(let level) = payload["severity"] {
                next["severity"] = .string(level >= 3 ? "high" : "low")
            }
            next["issuedAtTick"] = .integer(issuedAtTick)
            return next
        }
    }

    /// Turns a band back into a number and admits it discards the issue tick.
    static func alertDowngradeToV2() -> PayloadMigration {
        PayloadMigration(from: 3, to: 2, loss: .lossy(drops: ["issuedAtTick"])) { payload in
            var next = payload
            next["severity"] = .integer(payload["severity"] == .string("high") ? 4 : 1)
            next["issuedAtTick"] = nil
            return next
        }
    }

    /// Drops the field v2 added.
    static func alertDowngradeToV1() -> PayloadMigration {
        PayloadMigration(from: 2, to: 1, loss: .lossy(drops: ["confidence"])) { payload in
            var next = payload
            next["confidence"] = nil
            return next
        }
    }

    /// A step that claims to produce v2 and forgets the field v2 requires.
    /// Deliberately wrong — scenario three exists to catch it.
    static func toolUpgradeForgettingLocale() -> PayloadMigration {
        PayloadMigration(from: 1, to: 2) { $0 }
    }

    /// A step that fails outright.
    static func toolUpgradeThatThrows() -> PayloadMigration {
        PayloadMigration(from: 1, to: 2) { _ in
            throw DemoFailure.localeLookupUnavailable
        }
    }
}

/// A failure raised by a demo step, to show how a thrown error is reported.
enum DemoFailure: Error, CustomStringConvertible {
    case localeLookupUnavailable

    var description: String {
        "localeLookupUnavailable"
    }
}
