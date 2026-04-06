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
            if !accessibilityGranted {
                Divider()
                accessibilityBanner
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    RecentlyQuitView(monitor: monitor)
                    Divider()
                        .padding(.horizontal, 16)
                    WhitelistEditorView(whitelistManager: whitelistManager)
                }
            }
            footerSection
        }
        .frame(width: 320)
        .onAppear { checkAccessibility() }
    }

    private var headerSection: some View {
        HStack(spacing: 10) {
            headerIcon
            Text("Hush")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            HStack(spacing: 5) {
                Circle()
                    .fill(monitor.isEnabled ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 6, height: 6)
                Text(monitor.isEnabled ? "Active" : "Paused")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Toggle("", isOn: $monitor.isEnabled)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .scaleEffect(0.8)
                .tint(.indigo)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var headerIcon: some View {
        Image("HushIcon")
            .resizable()
            .interpolation(.high)
            .frame(width: 18, height: 18)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private var accessibilityBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 13))
            VStack(alignment: .leading, spacing: 1) {
                Text("Accessibility Required")
                    .font(.caption)
                    .fontWeight(.medium)
                Text("Needed to count open windows")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Grant") {
                requestAccessibility()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.mini)
            .tint(.orange)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.08))
    }

    private var footerSection: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 5) {
                Image(systemName: "arrow.up.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("Launch at Login")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                LaunchAtLoginToggle()
                    .controlSize(.mini)
                    .scaleEffect(0.8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            Divider()
            Button {
                NSApp.terminate(nil)
            } label: {
                Text("Quit Hush")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            .padding(.vertical, 6)
        }
    }

    private func checkAccessibility() {
        let granted = AXIsProcessTrusted()
        if granted != accessibilityGranted {
            print("[Hush] Accessibility permission changed: \(granted)")
        }
        accessibilityGranted = granted
    }

    private func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
