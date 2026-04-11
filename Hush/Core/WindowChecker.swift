import AppKit
import ApplicationServices

protocol WindowCheckerProtocol {
    func windowCount(for pid: pid_t) -> Int
    func isAccessibilityGranted() -> Bool
}

class WindowChecker: WindowCheckerProtocol {
    func windowCount(for pid: pid_t) -> Int {
        guard isAccessibilityGranted() else {
            print("[Hush] WindowChecker: Accessibility NOT granted, returning -1 (safe skip)")
            return -1
        }

        let axApp = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value)

        let axCount: Int
        switch result {
        case .success:
            axCount = (value as? [AXUIElement])?.count ?? 0
        case .noValue:
            axCount = 0
        default:
            print("[Hush] WindowChecker: AX API error (\(result.rawValue)) for pid \(pid), returning -1 (safe skip)")
            return -1
        }

        // FIX: Fullscreen apps quit unexpectedly during CMD+TAB (GitHub #1)
        //
        // Cause: When a fullscreen app lives on a separate macOS Space and the
        // user CMD+TABs away, the Accessibility API (kAXWindowsAttribute) can
        // report 0 windows — even though the fullscreen window still exists on
        // the other Space. Hush then passes all 6 gates and quits the app.
        //
        // Fix: When AX reports 0 windows, cross-check with CGWindowListCopyWindowInfo,
        // which can see windows across *all* Spaces including fullscreen. If CGWindowList
        // finds normal-layer (layer 0) windows that AX missed, we return that count
        // instead, preventing the false quit.
        if axCount == 0 {
            let cgCount = cgWindowCount(for: pid)
            if cgCount > 0 {
                print("[Hush] WindowChecker: pid \(pid) → AX reports 0 but CGWindowList found \(cgCount) window(s) (likely fullscreen on another Space)")
                return cgCount
            }
        }

        print("[Hush] WindowChecker: pid \(pid) → \(axCount) window(s)")
        return axCount
    }

    /// Uses CGWindowList to count normal-layer windows for a given PID.
    /// This API can see windows across all Spaces, including fullscreen.
    private func cgWindowCount(for pid: pid_t) -> Int {
        guard let windowList = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else {
            return 0
        }

        return windowList.filter { info in
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? Int32,
                  ownerPID == pid,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0 else {
                return false
            }
            return true
        }.count
    }

    func isAccessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }
}
