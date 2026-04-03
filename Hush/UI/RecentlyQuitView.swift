import SwiftUI
import AppKit

struct RecentlyQuitView: View {
    @ObservedObject var monitor: AppMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Recently Quit")
            if monitor.recentlyQuit.isEmpty {
                emptyState
            } else {
                ForEach(monitor.recentlyQuit) { record in
                    quitRow(record)
                }
            }
        }
        .padding(.bottom, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 22))
                .foregroundStyle(.secondary.opacity(0.4))
            Text("No apps quit yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private func quitRow(_ record: QuitRecord) -> some View {
        HStack(spacing: 10) {
            appIcon(bundleURL: record.bundleURL)
            VStack(alignment: .leading, spacing: 1) {
                Text(record.appName)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(record.quitDate, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Keep") {
                monitor.keepApp(record: record)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .onHover { hovering in
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
    }

    private func appIcon(bundleURL: URL?) -> some View {
        Group {
            if let url = bundleURL {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 26, height: 26)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
