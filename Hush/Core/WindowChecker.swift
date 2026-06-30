import AppKit
import ApplicationServices

protocol WindowCheckerProtocol {
    func windowCount(for pid: pid_t) -> Int
    func hasFullscreenWindow(for pid: pid_t) -> Bool
    func isAccessibilityGranted() -> Bool
}

class WindowChecker: WindowCheckerProtocol {
    // Counts an app's windows on the *current* Space via the Accessibility API.
    //
    // AX deliberately only sees the current Space — and that's exactly what we
    // want. Hush quits an app when the user *closes its last window*, which we
    // detect as this count dropping from ≥1 to 0 while staying on one Space
    // (see AppMonitor). Both real closes (Terminal destroys the window) and
    // "hide on close" apps (Calendar, GitHub Desktop, Electron apps hide the
    // window) make AX drop to 0, so both get quit. A window merely parked on
    // another desktop was never counted on this Space, so it never looks like a
    // close. Returns -1 on AX failure (treated as "has windows" — safe skip).
    func windowCount(for pid: pid_t) -> Int {
        guard isAccessibilityGranted() else {
            hushLog("WindowChecker: Accessibility NOT granted, returning -1 (safe skip)")
            return -1
        }

        let axApp = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value)

        let count: Int
        switch result {
        case .success:
            count = (value as? [AXUIElement])?.count ?? 0
        case .noValue:
            count = 0
        default:
            hushLog("WindowChecker: AX API error (\(result.rawValue)) for pid \(pid), returning -1 (safe skip)")
            count = -1
        }
        return count
    }

    func hasFullscreenWindow(for pid: pid_t) -> Bool {
        guard isAccessibilityGranted() else { return false }

        let axApp = AXUIElementCreateApplication(pid)
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else {
            return false
        }

        for window in windows {
            var fsValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &fsValue) == .success,
               let isFullscreen = fsValue as? Bool, isFullscreen {
                return true
            }
        }
        return false
    }

    func isAccessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }
}
