import SwiftUI
import ServiceManagement

private let accent = Color(red: 0.86, green: 0.33, blue: 0.24)

private let shortcutsHelp = "Runs the macOS Shortcuts “\(Integrations.shortcutNames[0])” when focus starts and “\(Integrations.shortcutNames[1])” when it ends. macOS asks you to add each one when you turn this on: click Add Shortcut."
private let slackHelp = "Needs a Slack user token (xoxp-…) with the scopes dnd:write and users.profile:write."

struct SettingsView: View {
    @ObservedObject var s: Settings
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var shortcutHint = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                section("Pomodoro", note: "Applies from the next cycle.") {
                    DurationRow(title: "Focus", minutes: $s.focusMinutes, range: 1...180)
                    Divider()
                    DurationRow(title: "Rest", minutes: $s.restMinutes, range: 1...60)
                }
                section("Keep awake", note: "Runs while Keep awake is on in the menu. One at a time.") {
                    CommandList(items: $s.keepAliveItems, exclusive: true) { on in s.keepAwake = on }
                }
                section("On rest", note: "Every enabled command runs when a rest starts.") {
                    CommandList(items: $s.restItems, exclusive: false)
                }
                section("Focus · Shortcuts") {
                    ToggleRow(title: "Run macOS Shortcuts",
                              subtitle: "Switches Focus / Do Not Disturb with the Shortcuts “\(Integrations.shortcutNames[0])” and “\(Integrations.shortcutNames[1])”. macOS asks you to add them: click Add Shortcut for each.",
                              isOn: $s.shortcutsEnabled)
                        .help(shortcutsHelp)
                        .onChange(of: s.shortcutsEnabled) { _, on in
                            guard on else { shortcutHint = ""; return }
                            showHint(Integrations.installMissingShortcuts())
                        }
                        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                            if s.shortcutsEnabled { showHint(Integrations.missingShortcuts()) }
                        }
                    if !shortcutHint.isEmpty {
                        Label(shortcutHint, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                section("Focus · Slack") {
                    ToggleRow(title: "Pause notifications and set status",
                              subtitle: "Snoozes Slack and shows “Focusing” as your status during focus.",
                              isOn: $s.slackEnabled)
                        .help(slackHelp)
                        .onChange(of: s.slackEnabled) { _, on in
                            if on && s.slackToken.isEmpty { NSWorkspace.shared.open(Integrations.slackAppURL) }
                        }
                    if s.slackEnabled { slackSetup }
                }
                section("General") {
                    ToggleRow(title: "Launch at login", subtitle: nil, isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, on in
                            do { on ? try SMAppService.mainApp.register() : try SMAppService.mainApp.unregister() }
                            catch { Log.write("launch at login: \(error)"); launchAtLogin = !on }
                        }
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(accent)
        .frame(width: 500, height: 680)
    }

    private var slackSetup: some View {
        VStack(alignment: .leading, spacing: 8) {
            SecureField("Slack user token (xoxp-…)", text: $s.slackToken).fieldStyle()
            if !s.slackToken.isEmpty && !s.slackToken.hasPrefix("xoxp-") {
                Label("User tokens start with xoxp-", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.red)
            }
            Text("1. Open Slack and create the app: it is pre-filled with the right scopes.\n2. Choose Install to Workspace.\n3. Copy the “User OAuth Token” and paste it above.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button { NSWorkspace.shared.open(Integrations.slackAppURL) } label: {
                Label("Get a token", systemImage: "arrow.up.right.square")
            }
            .buttonStyle(.link).font(.callout)
        }
    }

    private func section<Content: View>(_ title: String, note: String? = nil,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary).tracking(0.6)
                if let note { Text(note).font(.caption).foregroundStyle(.tertiary) }
            }
            .padding(.horizontal, 4)
            VStack(alignment: .leading, spacing: 12, content: content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(nsColor: .separatorColor).opacity(0.6)))
        }
    }

    private func showHint(_ missing: [String]) {
        shortcutHint = missing.isEmpty ? "" : "Click Add Shortcut in the Shortcuts window for: \(missing.joined(separator: ", "))."
    }
}

extension View {
    fileprivate func fieldStyle() -> some View {
        textFieldStyle(.plain)
            .padding(.horizontal, 9).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 7).fill(Color(nsColor: .textBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color(nsColor: .separatorColor)))
    }
}

private struct ToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn).labelsHidden().toggleStyle(.switch)
        }
    }
}

/// Slider for big moves, number field for exact values.
private struct DurationRow: View {
    let title: String
    @Binding var minutes: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 12) {
            Text(title).frame(width: 44, alignment: .leading)
            Slider(value: Binding(get: { Double(minutes) }, set: { minutes = Int($0) }),
                   in: Double(range.lowerBound)...Double(range.upperBound), step: 1)
            TextField("", value: Binding(get: { minutes }, set: { minutes = min(max($0, range.lowerBound), range.upperBound) }),
                      format: .number)
                .multilineTextAlignment(.trailing)
                .fieldStyle()
                .frame(width: 56)
            Text("min").foregroundStyle(.secondary)
        }
    }
}

/// Rows of command + description + switch + remove. `exclusive` lets only one switch be on.
private struct CommandList: View {
    @Binding var items: [CommandItem]
    let exclusive: Bool
    /// Called when the user flips a switch.
    var onToggle: (Bool) -> Void = { _ in }

    var body: some View {
        // Iterate values and bind by id: `ForEach($items)` reads a stale index after a removal and crashes.
        ForEach(items) { current in
            let item = binding(for: current)
            if current.id != items.first?.id { Divider() }
            CommandRow(item: item, builtIn: current.builtIn, enabled: enabledBinding(item)) {
                items.removeAll { $0.id == current.id }
            }
        }
        Button { items.append(CommandItem(enabled: !exclusive)) } label: {
            Label("Add command", systemImage: "plus")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(accent)
    }

    private func binding(for current: CommandItem) -> Binding<CommandItem> {
        Binding(get: { items.first { $0.id == current.id } ?? current },
                set: { new in if let i = items.firstIndex(where: { $0.id == current.id }) { items[i] = new } })
    }

    private func enabledBinding(_ item: Binding<CommandItem>) -> Binding<Bool> {
        Binding(get: { item.wrappedValue.enabled }, set: { on in
            if on && exclusive { for i in items.indices { items[i].enabled = false } }
            item.wrappedValue.enabled = on
            onToggle(on)
        })
    }
}

private struct CommandRow: View {
    @Binding var item: CommandItem
    let builtIn: Bool
    @Binding var enabled: Bool
    let remove: () -> Void
    @ObservedObject private var status = CommandStatus.shared
    @State private var missing: String?

    /// A failure from the last real run wins over the static lookup, while the command text is unchanged.
    private var problem: String? {
        if let f = status.failures[item.id], f.command == item.command { return f.message }
        return missing
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                if builtIn {
                    Text(item.detail)
                    Text(item.command).font(.system(.callout, design: .monospaced)).foregroundStyle(.secondary)
                } else {
                    TextField("Command, e.g. say \"Time to rest\"", text: $item.command)
                        .font(.system(.body, design: .monospaced))
                        .fieldStyle()
                    TextField("What it does (optional)", text: $item.detail)
                        .font(.callout)
                        .fieldStyle()
                }
                if let problem, enabled {
                    Label(problem, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
                }
            }
            VStack(spacing: 10) {
                Toggle("", isOn: $enabled).labelsHidden().toggleStyle(.switch)
                if !builtIn {
                    Button(action: remove) { Image(systemName: "trash") }
                        .buttonStyle(.borderless).foregroundStyle(.secondary).help("Remove")
                }
            }
        }
        .task(id: item.command) {
            guard !builtIn else { return }
            let command = item.command
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }
            missing = await CommandCheck.missing(command)
        }
    }
}
