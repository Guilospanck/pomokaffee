import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var s: Settings
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Pomodoro (applies from the next cycle)") {
                Stepper("Focus: \(s.focusMinutes) min", value: $s.focusMinutes, in: 1...180)
                Stepper("Rest: \(s.restMinutes) min", value: $s.restMinutes, in: 1...60)
            }
            Section("Keep alive") {
                Toggle("Keep Mac awake (caffeinate -disu)", isOn: $s.keepAwake)
            }
            Section("On rest") {
                Toggle("Clean disk caches", isOn: $s.cleanupEnabled)
                TextField("Command", text: $s.cleanupCommand).disabled(!s.cleanupEnabled)
                Text("Extra commands, one per line:").font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $s.restScripts)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 70)
            }
            Section("On focus") {
                Toggle("Run macOS Shortcuts to toggle Focus / Do Not Disturb", isOn: $s.shortcutsEnabled)
                TextField("Shortcut when focus starts", text: $s.shortcutOn).disabled(!s.shortcutsEnabled)
                TextField("Shortcut when focus ends", text: $s.shortcutOff).disabled(!s.shortcutsEnabled)
                Toggle("Slack: pause notifications + set status", isOn: $s.slackEnabled)
                SecureField("Slack user token (xoxp-…, dnd:write + users.profile:write)", text: $s.slackToken)
                    .disabled(!s.slackEnabled)
            }
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        do { on ? try SMAppService.mainApp.register() : try SMAppService.mainApp.unregister() }
                        catch { Log.write("launch at login: \(error)"); launchAtLogin = !on }
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 620)
    }
}
