import AppKit
import Combine

class WhitelistManager: ObservableObject {
    static let hardcodedDefaults: Set<String> = [
        "com.apple.finder",
        "com.apple.systempreferences",
        "com.apple.dt.Xcode",
    ]

    private let userDefaultsKey = "hushWhitelist"
    private let defaults: UserDefaults

    @Published private(set) var whitelistedBundleIDs: Set<String>

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        let saved = Set(userDefaults.stringArray(forKey: "hushWhitelist") ?? [])
        self.whitelistedBundleIDs = saved.union(Self.hardcodedDefaults)
    }

    func add(bundleID: String) {
        whitelistedBundleIDs.insert(bundleID)
        persist()
    }

    func remove(bundleID: String) {
        guard !Self.hardcodedDefaults.contains(bundleID) else { return }
        whitelistedBundleIDs.remove(bundleID)
        persist()
    }

    func isWhitelisted(bundleID: String) -> Bool {
        whitelistedBundleIDs.contains(bundleID)
    }

    func runningRegularApps() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .filter { $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private func persist() {
        let userAdded = whitelistedBundleIDs.subtracting(Self.hardcodedDefaults)
        defaults.set(Array(userAdded), forKey: userDefaultsKey)
    }
}
