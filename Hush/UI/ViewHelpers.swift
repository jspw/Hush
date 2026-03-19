import SwiftUI

func sectionHeader(_ title: String) -> some View {
    Text(title)
        .font(.caption)
        .foregroundColor(.secondary)
        .textCase(.uppercase)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
}
