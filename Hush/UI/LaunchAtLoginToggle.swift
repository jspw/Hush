import SwiftUI
import ServiceManagement

struct LaunchAtLoginToggle: View {
    @State private var isEnabled: Bool = false

    var body: some View {
        Toggle("", isOn: $isEnabled)
            .toggleStyle(.switch)
            .labelsHidden()
            .onAppear { isEnabled = currentStatus() }
            .onChange(of: isEnabled) { newValue in
                setLaunchAtLogin(newValue)
            }
    }

    private func currentStatus() -> Bool {
        SMAppService.mainApp.status == .enabled
    }

    private func setLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            isEnabled = currentStatus()
        }
    }
}
