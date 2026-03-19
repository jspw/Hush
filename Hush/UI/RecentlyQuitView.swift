import SwiftUI

struct RecentlyQuitView: View {
    @ObservedObject var monitor: AppMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Recently Quit")
            if monitor.recentlyQuit.isEmpty {
                Text("Nothing yet")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            } else {
                ForEach(monitor.recentlyQuit) { record in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.appName)
                                .font(.subheadline)
                            Text(record.quitDate, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Keep") {
                            monitor.keepApp(record: record)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .onHover { hovering in
                            if hovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
            }
        }
    }
}
