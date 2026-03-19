import SwiftUI
import AppKit
import ApplicationServices

struct PopoverView: View {
    @ObservedObject var monitor: AppMonitor
    @ObservedObject var whitelistManager: WhitelistManager
    @State private var accessibilityGranted: Bool = AXIsProcessTrusted()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider()
            if !accessibilityGranted {
                accessibilityBanner
                Divider()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    RecentlyQuitView(monitor: monitor)
                    Divider()
                    WhitelistEditorView(whitelistManager: whitelistManager)
                }
            }
            Divider()
            footerSection
        }
        .frame(width: 320)
        .onAppear { checkAccessibility() }
    }

    private var headerSection: some View {
        HStack {
            Text("Hush")
                .font(.headline)
            Spacer()
            Toggle("", isOn: $monitor.isEnabled)
                .toggleStyle(.switch)
                .tint(monitor.isEnabled ? .green : .gray)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var accessibilityBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text("Accessibility access required")
                .font(.caption)
            Spacer()
            Button("Open Settings") {
                openAccessibilitySettings()
            }
            .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
    }

    private var footerSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Launch at Login")
                    .font(.subheadline)
                Spacer()
                LaunchAtLoginToggle()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Button("Quit Hush") {
                NSApp.terminate(nil)
            }
            .foregroundColor(.red)
            .padding(.bottom, 12)
        }
    }

    private func checkAccessibility() {
        let granted = AXIsProcessTrusted()
        if granted != accessibilityGranted {
            print("[Hush] Accessibility permission changed: \(granted)")
        }
        accessibilityGranted = granted
    }

    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
