import AppKit
import SwiftUI

class MenuBarController {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?

    private let monitor: AppMonitor
    private let whitelistManager: WhitelistManager

    init(monitor: AppMonitor, whitelistManager: WhitelistManager) {
        self.monitor = monitor
        self.whitelistManager = whitelistManager
    }

    func setup() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "moon.zzz.fill", accessibilityDescription: "Hush")
        item.button?.action = #selector(togglePopover)
        item.button?.target = self
        statusItem = item

        let pop = NSPopover()
        pop.contentSize = NSSize(width: 320, height: 460)
        pop.behavior = .transient
        pop.contentViewController = NSHostingController(
            rootView: PopoverView(monitor: monitor, whitelistManager: whitelistManager)
        )
        popover = pop
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let pop = popover else { return }
        if pop.isShown {
            pop.performClose(nil)
            removeEventMonitor()
        } else {
            // Recreate the content view so accessibility state is fresh
            pop.contentViewController = NSHostingController(
                rootView: PopoverView(monitor: monitor, whitelistManager: whitelistManager)
            )
            pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            pop.contentViewController?.view.window?.makeKey()
            addEventMonitor()
        }
    }

    private func addEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.popover?.performClose(nil)
            self?.removeEventMonitor()
        }
    }

    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
