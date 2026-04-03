import SwiftUI
import AppKit

struct WhitelistEditorView: View {
    @ObservedObject var whitelistManager: WhitelistManager
    @State private var showingAddSheet = false

    private var userEntries: [String] {
        whitelistManager.whitelistedBundleIDs
            .subtracting(WhitelistManager.hardcodedDefaults)
            .sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                sectionHeader("Never Quit")
                Spacer()
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.indigo)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                .padding(.trailing, 14)
                .padding(.top, 8)
            }

            ForEach(WhitelistManager.hardcodedDefaults.sorted(), id: \.self) { bundleID in
                builtInRow(bundleID: bundleID)
            }

            ForEach(userEntries, id: \.self) { bundleID in
                userRow(bundleID: bundleID)
            }

            if userEntries.isEmpty {
                Text("Apps added here will never be auto-quit")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
            }
        }
        .padding(.bottom, 4)
        .sheet(isPresented: $showingAddSheet) {
            AddToWhitelistSheet(whitelistManager: whitelistManager, isPresented: $showingAddSheet)
        }
    }

    private func builtInRow(bundleID: String) -> some View {
        HStack(spacing: 10) {
            appIconView(for: bundleID)
            Text(displayName(for: bundleID))
                .font(.subheadline)
                .lineLimit(1)
            Spacer()
            Image(systemName: "lock.fill")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private func userRow(bundleID: String) -> some View {
        HStack(spacing: 10) {
            appIconView(for: bundleID)
            Text(displayName(for: bundleID))
                .font(.subheadline)
                .lineLimit(1)
            Spacer()
            Button {
                whitelistManager.remove(bundleID: bundleID)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private func appIconView(for bundleID: String) -> some View {
        Group {
            if let icon = resolveIcon(for: bundleID) {
                Image(nsImage: icon)
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

    private func resolveIcon(for bundleID: String) -> NSImage? {
        if let running = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }),
           let icon = running.icon {
            return icon
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return nil
    }

    private func displayName(for bundleID: String) -> String {
        if let running = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }),
           let name = running.localizedName {
            return name
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return url.deletingPathExtension().lastPathComponent
        }
        return bundleID
    }
}

struct AddToWhitelistSheet: View {
    @ObservedObject var whitelistManager: WhitelistManager
    @Binding var isPresented: Bool

    private var candidates: [NSRunningApplication] {
        whitelistManager.runningRegularApps().filter {
            !whitelistManager.isWhitelisted(bundleID: $0.bundleIdentifier ?? "")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Never Quit")
                    .font(.headline)
                    .padding()
                Spacer()
                Button("Done") { isPresented = false }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.indigo)
                    .padding()
            }
            Divider()
            if candidates.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("All running apps are already protected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List(candidates, id: \.processIdentifier) { app in
                    HStack(spacing: 10) {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .interpolation(.high)
                                .frame(width: 28, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        Text(app.localizedName ?? app.bundleIdentifier ?? "Unknown")
                            .font(.subheadline)
                        Spacer()
                        Button("Add") {
                            if let bid = app.bundleIdentifier {
                                whitelistManager.add(bundleID: bid)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .onHover { hovering in
                            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(width: 300, height: 360)
    }
}
