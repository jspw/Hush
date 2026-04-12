import AppKit
import ApplicationServices

protocol WindowCheckerProtocol {
    func windowCount(for pid: pid_t) -> Int
    func hasFullscreenWindow(for pid: pid_t) -> Bool
    func isAccessibilityGranted() -> Bool
}

class WindowChecker: WindowCheckerProtocol {
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
        hushLog("WindowChecker: pid \(pid) → \(count) window(s)")
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
