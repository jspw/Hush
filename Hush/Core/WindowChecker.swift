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

        let count: Int
        switch result {
        case .success:
            count = (value as? [AXUIElement])?.count ?? 0
        case .noValue:
            count = 0
        default:
            print("[Hush] WindowChecker: AX API error (\(result.rawValue)) for pid \(pid), returning -1 (safe skip)")
            count = -1
        }
        print("[Hush] WindowChecker: pid \(pid) → \(count) window(s)")
        return count
    }

    func isAccessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }
}
