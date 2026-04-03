import Foundation

struct QuitRecord: Identifiable, Codable {
    let id: UUID
    let appName: String
    let bundleIdentifier: String
    let bundleURL: URL?
    let quitDate: Date

    init(id: UUID = UUID(), appName: String, bundleIdentifier: String, bundleURL: URL? = nil, quitDate: Date = Date()) {
        self.id = id
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.bundleURL = bundleURL
        self.quitDate = quitDate
    }
}
