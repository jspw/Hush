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
            HStack {
                sectionHeader("Whitelist")
                Spacer()
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                .padding(.trailing, 16)
            }

            ForEach(WhitelistManager.hardcodedDefaults.sorted(), id: \.self) { bundleID in
                HStack {
                    Text(displayName(for: bundleID))
                        .font(.subheadline)
                    Text("(built-in)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 5)
            }

            ForEach(userEntries, id: \.self) { bundleID in
                HStack {
                    Text(displayName(for: bundleID))
                        .font(.subheadline)
                    Spacer()
                    Button {
                        whitelistManager.remove(bundleID: bundleID)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 5)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddToWhitelistSheet(whitelistManager: whitelistManager, isPresented: $showingAddSheet)
        }
    }

    private func displayName(for bundleID: String) -> String {
        NSWorkspace.shared.runningApplications
            .first { $0.bundleIdentifier == bundleID }?
            .localizedName ?? bundleID
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
                Text("Add to Whitelist")
                    .font(.headline)
                    .padding()
                Spacer()
                Button("Done") { isPresented = false }
                    .padding()
            }
            Divider()
            if candidates.isEmpty {
                Text("No running apps to add.")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List(candidates, id: \.processIdentifier) { app in
                    HStack {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 20, height: 20)
                        }
                        Text(app.localizedName ?? app.bundleIdentifier ?? "Unknown")
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
                }
            }
        }
        .frame(width: 300, height: 360)
    }
}
