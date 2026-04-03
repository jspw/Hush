import SwiftUI

func sectionHeader(_ title: String) -> some View {
    Text(title)
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.secondary)
        .kerning(0.5)
        .textCase(.uppercase)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
}
