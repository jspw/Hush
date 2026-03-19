import Foundation

struct AppEntry: Identifiable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    let displayName: String
}
