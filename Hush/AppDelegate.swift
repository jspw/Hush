import AppKit
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var appMonitor: AppMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[Hush] App launched")
        NSApp.setActivationPolicy(.accessory)

        // Prompt for Accessibility if not granted (opens System Settings automatically)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        print("[Hush] Accessibility granted: \(trusted)")

        let checker = WindowChecker()

        let whitelist = WhitelistManager()
        print("[Hush] Whitelist: \(whitelist.whitelistedBundleIDs)")

        let quitter = AppQuitter()
        let monitor = AppMonitor(windowChecker: checker, whitelistManager: whitelist, quitter: quitter)
        appMonitor = monitor

        menuBarController = MenuBarController(monitor: monitor, whitelistManager: whitelist)
        menuBarController?.setup()
        print("[Hush] Menu bar set up")

        requestNotificationPermission()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            print("[Hush] Notification permission granted: \(granted), error: \(error?.localizedDescription ?? "none")")
        }
    }
}
