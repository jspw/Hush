import AppKit
import UserNotifications

class AppQuitter {
    func quit(app: NSRunningApplication, onQuit: @escaping (QuitRecord) -> Void) {
        let name = app.localizedName ?? "Unknown"
        let bundleID = app.bundleIdentifier ?? ""

        print("[Hush] ✂ Quitting \"\(name)\" (\(bundleID), pid \(app.processIdentifier))")
        app.terminate()

        let record = QuitRecord(appName: name, bundleIdentifier: bundleID)
        onQuit(record)

        sendNotification(appName: name)
    }

    private func sendNotification(appName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Hush"
        content.body = "\(appName) was quit (no open windows)."

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { _ in }
    }
}
