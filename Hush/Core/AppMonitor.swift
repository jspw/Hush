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

    // Tracks apps known to have fullscreen windows. Populated when apps are
    // frontmost (via the poll timer) and checked on deactivation. Fixes GitHub #1:
    // CMD+TAB from a fullscreen app causes AX to report 0 windows (because the
    // window is on another Space), which would otherwise trigger a false quit.
    private var fullscreenApps: Set<pid_t> = []

    // Apps we've observed displaying ≥1 window *since the last Space change*. We
    // only ever quit an app in this set, so quitting requires having actually
    // seen a window on the current Space go away (a real close), not just an app
    // reporting 0 windows. This filters out:
    //   • still-launching apps (Postman/Numbers), background helpers, and
    //     incoming-call panels AX can't see — never had a window, never quit;
    //   • windows merely parked on another desktop — never counted on *this*
    //     Space, so they never look like a close (the set is cleared on every
    //     active-Space change and rebuilt from the new Space).
    // Populated whenever a window count > 0 is observed for a PID — on activate,
    // on poll, and via the post-Space-change rebuild.
    private var appsWithKnownWindows: Set<pid_t> = []

    // Timestamp of the last Space switch. Switching Spaces deactivates the
    // previously-frontmost app and makes AX report 0 windows for windows that
    // merely moved to another Space, which would trigger a false quit. We
    // suppress quits for a short grace period after any Space change.
    private var lastSpaceChangeAt: Date = .distantPast
    private let spaceChangeGracePeriod: TimeInterval = 2.0

    // Apps launched within this window legitimately have 0 windows while they
    // start up (and during update/relaunch flows). Don't quit them yet.
    private let launchGracePeriod: TimeInterval = 3.0

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

        // When an app comes to the front, immediately sample its window count on
        // the current Space. This is how an app earns quit-eligibility: we record
        // that we've seen one of its windows here. Doing it on activation (not
        // just the 2s poll) catches windows that open and close quickly, which
        // the poll would otherwise miss entirely. Never quits — only records.
        let activate = nc.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            self?.recordWindowsOnActivate(note)
        }

        let terminate = nc.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let name = app.localizedName ?? "?"
            if self?.pendingChecks[app.processIdentifier] != nil {
                hushLog("Event: \"\(name)\" terminated — cancelling pending check")
            } else {
                hushLog("Event: \"\(name)\" terminated")
            }
            self?.pendingChecks[app.processIdentifier]?.cancel()
            self?.pendingChecks.removeValue(forKey: app.processIdentifier)
            self?.fullscreenApps.remove(app.processIdentifier)
            self?.appsWithKnownWindows.remove(app.processIdentifier)
        }

        // A Space switch deactivates the previously-frontmost app and makes AX
        // report 0 windows for windows that just moved to another Space. Record
        // the time so checks within the grace period don't false-quit.
        let spaceChange = nc.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.lastSpaceChangeAt = Date()
            // Window counts are per-Space, so observations from the previous
            // Space no longer apply. Clear them, then immediately rebuild from
            // the *new* Space (see rebuild method) so every app that still has a
            // window here stays quit-eligible — not just the frontmost one.
            self.appsWithKnownWindows.removeAll()
            hushLog("Event: active Space changed — cleared window history, suppressing quits for \(self.spaceChangeGracePeriod)s")
            self.rebuildKnownWindowsForCurrentSpace()
        }

        observers = [deactivate, hide, activate, terminate, spaceChange]
    }

    /// Records that an app has a window on the current Space the moment it's
    /// activated, so it becomes quit-eligible even if its window is short-lived.
    /// Never triggers a quit.
    private func recordWindowsOnActivate(_ note: Notification) {
        guard isEnabled,
              let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.activationPolicy == .regular,
              let bid = app.bundleIdentifier,
              bid != Bundle.main.bundleIdentifier,
              !whitelistManager.isWhitelisted(bundleID: bid)
        else { return }

        let pid = app.processIdentifier
        if windowChecker.hasFullscreenWindow(for: pid) {
            fullscreenApps.insert(pid)
        }
        if windowChecker.windowCount(for: pid) > 0 {
            appsWithKnownWindows.insert(pid)
        }
    }

    /// After a Space change the window history is stale (AX counts are
    /// per-Space). Rebuild it by sampling *every* regular app's window count on
    /// the new current Space, so an app that still has a window here stays
    /// quit-eligible even if it isn't frontmost. Apps whose windows are on
    /// another desktop report 0 and are left out, preserving cross-desktop
    /// protection. Runs slightly delayed (to let the window server settle, and
    /// inside the quit grace window) on the background queue since it touches
    /// many AX elements.
    private func rebuildKnownWindowsForCurrentSpace() {
        checkQueue.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self else { return }
            var rebuilt: Set<pid_t> = []
            for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
                guard let bid = app.bundleIdentifier,
                      bid != Bundle.main.bundleIdentifier,
                      !self.whitelistManager.isWhitelisted(bundleID: bid),
                      !app.isTerminated else { continue }
                if self.windowChecker.windowCount(for: app.processIdentifier) > 0 {
                    rebuilt.insert(app.processIdentifier)
                }
            }
            DispatchQueue.main.async {
                self.appsWithKnownWindows.formUnion(rebuilt)
                hushLog("Rebuilt window history for current Space: \(rebuilt.count) app(s) with a window here")
            }
        }
    }

    private func isWithinSpaceChangeGrace() -> Bool {
        Date().timeIntervalSince(lastSpaceChangeAt) < spaceChangeGracePeriod
    }

    /// Shared gate for the 0-window case: returns true only when it's safe to
    /// quit. Logs the reason when it isn't. Used by both the event-driven check
    /// and the frontmost poll so they stay in sync.
    private func isSafeToQuitWindowlessApp(_ app: NSRunningApplication, name: String) -> Bool {
        if isWithinSpaceChangeGrace() {
            hushLog("  ✗ Skipped: Space changed recently — \"\(name)\" window may be on another Space")
            return false
        }
        if let launchDate = app.launchDate {
            let elapsed = Date().timeIntervalSince(launchDate)
            if elapsed < launchGracePeriod {
                hushLog("  ✗ Skipped: \"\(name)\" launched \(String(format: "%.1f", elapsed))s ago — still starting up")
                return false
            }
        }
        if !appsWithKnownWindows.contains(app.processIdentifier) {
            hushLog("  ✗ Skipped: never observed a window for \"\(name)\" — not quitting")
            return false
        }
        return true
    }

    private func handleAppEvent(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        let pid = app.processIdentifier
        let name = app.localizedName ?? "?"
        let event = note.name == NSWorkspace.didDeactivateApplicationNotification ? "deactivated" : "hidden"
        hushLog("Event: \"\(name)\" \(event) (pid \(pid))")

        // If the app is (or was) fullscreen, AX may report 0 windows once it
        // moves to another Space. Don't schedule a check at all.
        if fullscreenApps.contains(pid) || windowChecker.hasFullscreenWindow(for: pid) {
            hushLog("  ✗ Skipped: \"\(name)\" has fullscreen window(s)")
            return
        }

        scheduleCheck(for: app)
    }

    private func scheduleCheck(for app: NSRunningApplication) {
        let pid = app.processIdentifier
        pendingChecks[pid]?.cancel()

        let work = DispatchWorkItem { [weak self] in
            self?.performCheck(app: app)
        }
        pendingChecks[pid] = work
        checkQueue.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    private func performCheck(app: NSRunningApplication) {
        let name = app.localizedName ?? "?"
        let bundleID = app.bundleIdentifier ?? "(none)"
        hushLog("Checking \"\(name)\" (\(bundleID))...")

        guard isEnabled else {
            hushLog("  ✗ Skipped: Hush is disabled")
            return
        }
        guard !app.isTerminated else {
            hushLog("  ✗ Skipped: already terminated")
            return
        }
        guard app.activationPolicy == .regular else {
            let policy = app.activationPolicy == .accessory ? "accessory (background app)" : "prohibited"
            hushLog("  ✗ Skipped: activation policy is .\(policy)")
            return
        }
        guard let bid = app.bundleIdentifier else {
            hushLog("  ✗ Skipped: no bundle identifier")
            return
        }
        guard !whitelistManager.isWhitelisted(bundleID: bid) else {
            hushLog("  ✗ Skipped: whitelisted")
            return
        }
        guard bid != Bundle.main.bundleIdentifier else {
            hushLog("  ✗ Skipped: that's us (Hush)")
            return
        }

        let count = windowChecker.windowCount(for: app.processIdentifier)
        guard count == 0 else {
            if count > 0 { appsWithKnownWindows.insert(app.processIdentifier) }
            hushLog("  ✗ Skipped: has \(count) window(s)")
            return
        }

        guard isSafeToQuitWindowlessApp(app, name: name) else { return }

        hushLog("  ✓ All gates passed — quitting \"\(name)\"")

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard !app.isTerminated else {
                hushLog("  ✗ Skipped: terminated before we could quit")
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

        guard !app.isTerminated else { return }
        guard app.activationPolicy == .regular else { return }
        guard let bundleID = app.bundleIdentifier else { return }
        guard bundleID != Bundle.main.bundleIdentifier else { return }
        guard !whitelistManager.isWhitelisted(bundleID: bundleID) else { return }
        if pendingChecks[pid] != nil { return }

        // Cache fullscreen state while the app is frontmost (AX can see the
        // windows on the current Space). This is checked later on deactivation
        // in case the app moves to another Space.
        if windowChecker.hasFullscreenWindow(for: pid) {
            fullscreenApps.insert(pid)
        } else {
            fullscreenApps.remove(pid)
        }

        let count = windowChecker.windowCount(for: pid)
        if count > 0 { appsWithKnownWindows.insert(pid) }

        if count == 0 {
            let name = app.localizedName ?? "?"
            guard isSafeToQuitWindowlessApp(app, name: name) else { return }
            hushLog("Poll: \"\(name)\" is frontmost with 0 windows — quitting")
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
