import AppKit
import Combine

class AppMonitor: ObservableObject {
    @Published private(set) var recentlyQuit: [QuitRecord] = []
    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "hushEnabled") }
    }

    private let windowChecker: WindowCheckerProtocol
    private let whitelistManager: WhitelistManager
    private let quitter: AppQuitter
    private var pendingChecks: [pid_t: DispatchWorkItem] = [:]
    private var observers: [Any] = []
    private let checkQueue = DispatchQueue(label: "hush.check", qos: .utility)
    private var pollTimer: Timer?
    private var lastFrontmostPID: pid_t = -1
    private var lastFrontmostWindowCount: Int = -1

    init(windowChecker: WindowCheckerProtocol,
         whitelistManager: WhitelistManager,
         quitter: AppQuitter) {
        self.windowChecker = windowChecker
        self.whitelistManager = whitelistManager
        self.quitter = quitter
        self.isEnabled = UserDefaults.standard.object(forKey: "hushEnabled") as? Bool ?? true
        setupObservers()
        startPolling()
    }

    private func setupObservers() {
        let nc = NSWorkspace.shared.notificationCenter

        let deactivate = nc.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            self?.handleAppEvent(note)
        }

        let hide = nc.addObserver(
            forName: NSWorkspace.didHideApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            self?.handleAppEvent(note)
        }

        let terminate = nc.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let name = app.localizedName ?? "?"
            if self?.pendingChecks[app.processIdentifier] != nil {
                print("[Hush] Event: \"\(name)\" terminated — cancelling pending check")
            } else {
                print("[Hush] Event: \"\(name)\" terminated")
            }
            self?.pendingChecks[app.processIdentifier]?.cancel()
            self?.pendingChecks.removeValue(forKey: app.processIdentifier)
        }

        observers = [deactivate, hide, terminate]
    }

    private func handleAppEvent(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        let name = app.localizedName ?? "?"
        let event = note.name == NSWorkspace.didDeactivateApplicationNotification ? "deactivated" : "hidden"
        print("[Hush] Event: \"\(name)\" \(event) (pid \(app.processIdentifier))")
        // Reset poll cache so the new frontmost app gets checked
        lastFrontmostPID = -1
        lastFrontmostWindowCount = -1
        scheduleCheck(for: app)
    }

    private func scheduleCheck(for app: NSRunningApplication) {
        let pid = app.processIdentifier
        let name = app.localizedName ?? "?"
        if pendingChecks[pid] != nil {
            print("[Hush] Cancelling previous pending check for \"\(name)\"")
        }
        pendingChecks[pid]?.cancel()

        let work = DispatchWorkItem { [weak self] in
            self?.performCheck(app: app)
        }
        pendingChecks[pid] = work
        print("[Hush] Scheduled check for \"\(name)\" in 0.8s")
        checkQueue.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    private func performCheck(app: NSRunningApplication) {
        let name = app.localizedName ?? "?"
        let bundleID = app.bundleIdentifier ?? "(none)"
        print("[Hush] Checking \"\(name)\" (\(bundleID))...")

        guard isEnabled else {
            print("[Hush]   ✗ Skipped: Hush is disabled")
            return
        }
        guard !app.isTerminated else {
            print("[Hush]   ✗ Skipped: already terminated")
            return
        }
        guard app.activationPolicy == .regular else {
            let policy = app.activationPolicy == .accessory ? "accessory (background app)" : "prohibited"
            print("[Hush]   ✗ Skipped: activation policy is .\(policy)")
            return
        }
        guard let bid = app.bundleIdentifier else {
            print("[Hush]   ✗ Skipped: no bundle identifier")
            return
        }
        guard !whitelistManager.isWhitelisted(bundleID: bid) else {
            print("[Hush]   ✗ Skipped: whitelisted")
            return
        }
        guard bid != Bundle.main.bundleIdentifier else {
            print("[Hush]   ✗ Skipped: that's us (Hush)")
            return
        }

        let count = windowChecker.windowCount(for: app.processIdentifier)
        guard count == 0 else {
            print("[Hush]   ✗ Skipped: has \(count) window(s)")
            return
        }

        print("[Hush]   ✓ All gates passed — quitting \"\(name)\"")

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard !app.isTerminated else {
                print("[Hush]   ✗ Skipped: terminated before we could quit")
                return
            }
            self.quitter.quit(app: app) { record in
                self.recentlyQuit.insert(record, at: 0)
                if self.recentlyQuit.count > 20 {
                    self.recentlyQuit = Array(self.recentlyQuit.prefix(20))
                }
            }
        }
    }

    // MARK: - Frontmost App Polling
    // Catches the case where user closes the last window but the app stays focused.
    // Workspace notifications only fire on deactivation, not on window close.

    private func startPolling() {
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkFrontmostApp()
        }
        timer.tolerance = 1.0  // Let macOS coalesce — saves energy
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func checkFrontmostApp() {
        guard isEnabled else { return }
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let pid = app.processIdentifier

        // Fast exit: skip all work if frontmost app hasn't changed and had windows last time
        if pid == lastFrontmostPID && lastFrontmostWindowCount > 0 {
            return
        }

        guard !app.isTerminated else { return }
        guard app.activationPolicy == .regular else { return }
        guard let bundleID = app.bundleIdentifier else { return }
        guard bundleID != Bundle.main.bundleIdentifier else { return }
        guard !whitelistManager.isWhitelisted(bundleID: bundleID) else { return }
        if pendingChecks[pid] != nil { return }

        let count = windowChecker.windowCount(for: pid)
        lastFrontmostPID = pid
        lastFrontmostWindowCount = count

        if count == 0 {
            let name = app.localizedName ?? "?"
            print("[Hush] Poll: \"\(name)\" is frontmost with 0 windows — quitting")
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard !app.isTerminated else { return }
                self.quitter.quit(app: app) { record in
                    self.recentlyQuit.insert(record, at: 0)
                    if self.recentlyQuit.count > 20 {
                        self.recentlyQuit = Array(self.recentlyQuit.prefix(20))
                    }
                }
            }
        }
    }

    func keepApp(record: QuitRecord) {
        whitelistManager.add(bundleID: record.bundleIdentifier)
        recentlyQuit.removeAll { $0.id == record.id }
    }

    deinit {
        let nc = NSWorkspace.shared.notificationCenter
        observers.forEach { nc.removeObserver($0) }
        pollTimer?.invalidate()
        pendingChecks.values.forEach { $0.cancel() }
    }
}
