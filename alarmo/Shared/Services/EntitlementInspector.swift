import Foundation

enum EntitlementInspector {
    private static let embeddedProvisionPath = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision")
    private static var cachedEntitlements: [String: Any]? = loadEmbeddedEntitlements()

    static func hasEntitlement(_ key: String) -> Bool {
        // App Store/TestFlight builds usually don't have embedded.mobileprovision.
        // In that case we return true and let the system permission API decide.
        guard let entitlements = cachedEntitlements else {
            // If we do have a provisioning profile but couldn't parse entitlements,
            // fail closed to avoid calling capability APIs without signed access.
            return embeddedProvisionPath == nil
        }

        guard let value = entitlements[key] else { return false }
        return normalizeEntitlementValue(value)
    }

    static var hasHealthKitAccess: Bool {
        hasEntitlement("com.apple.developer.healthkit")
            || hasEntitlement("com.apple.developer.healthkit.access")
    }

    static var hasFamilyControlsAccess: Bool {
        hasEntitlement("com.apple.developer.family-controls")
    }

    static var hasAppleSignInAccess: Bool {
        hasEntitlement("com.apple.developer.applesignin")
    }

    static var hasCriticalAlertsAccess: Bool {
        hasEntitlement("com.apple.developer.usernotifications.critical-alerts")
    }

    private static func loadEmbeddedEntitlements() -> [String: Any]? {
        guard let path = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision"),
              let rawData = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let plistStart = rawData.range(of: Data("<plist".utf8)),
              let plistEndTagRange = rawData.range(of: Data("</plist>".utf8)) else {
            return nil
        }

        let plistEnd = plistEndTagRange.upperBound
        guard plistStart.lowerBound < plistEnd else { return nil }

        let plistData = rawData.subdata(in: plistStart.lowerBound..<plistEnd)
        guard
              let plist = try? PropertyListSerialization.propertyList(
                from: plistData,
                options: [],
                format: nil
              ) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any] else {
            return nil
        }

        return entitlements
    }

    private static func normalizeEntitlementValue(_ value: Any) -> Bool {
        if let boolValue = value as? Bool { return boolValue }
        if let stringValue = value as? String { return !stringValue.isEmpty }
        if let arrayValue = value as? [Any] { return !arrayValue.isEmpty }
        if let dictionaryValue = value as? [String: Any] { return !dictionaryValue.isEmpty }
        return true
    }
}
