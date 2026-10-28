import Foundation

/// A shell command the user can switch on or off. Used for keep-alive and rest commands.
struct CommandItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var command = ""
    var detail = ""
    var enabled = true
    /// The built-in caffeinate row can be switched off but not removed.
    var builtIn = false

    static let caffeinateID = UUID(uuidString: "CAFFE14E-0000-4000-8000-000000000001")!
    static let caffeinate = CommandItem(id: caffeinateID, command: "caffeinate -disu",
                                        detail: "Caffeinate: keep the Mac awake", enabled: false, builtIn: true)
}

/// User preferences, persisted in UserDefaults.
final class Settings: ObservableObject {
    static let shared = Settings()
    private let d = UserDefaults.standard

    @Published var focusMinutes: Int { didSet { d.set(focusMinutes, forKey: "focusMinutes") } }
    @Published var restMinutes: Int { didSet { d.set(restMinutes, forKey: "restMinutes") } }
    @Published var keepAwake: Bool { didSet { d.set(keepAwake, forKey: "keepAwake") } }
    /// Keep-alive commands; at most one is enabled, and that one runs while `keepAwake` is on.
    @Published var keepAliveItems: [CommandItem] { didSet { Self.save(keepAliveItems, "keepAliveItems") } }
    /// Run at the start of every rest, each enabled one.
    @Published var restItems: [CommandItem] { didSet { Self.save(restItems, "restItems") } }
    @Published var shortcutsEnabled: Bool { didSet { d.set(shortcutsEnabled, forKey: "shortcutsEnabled") } }
    @Published var slackEnabled: Bool { didSet { d.set(slackEnabled, forKey: "slackEnabled") } }
    /// Kept in the Keychain, never in UserDefaults.
    @Published var slackToken: String { didSet { Keychain.set("slackToken", slackToken) } }

    /// The keep-alive command that would run, if any is enabled and non-empty.
    var activeKeepAlive: CommandItem? {
        keepAliveItems.first { $0.enabled && !$0.command.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private static func save(_ items: [CommandItem], _ key: String) {
        if let data = try? JSONEncoder().encode(items) { UserDefaults.standard.set(data, forKey: key) }
    }

    private static func load(_ key: String) -> [CommandItem]? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode([CommandItem].self, from: $0) }
    }

    private init() {
        func int(_ k: String, _ def: Int) -> Int { UserDefaults.standard.object(forKey: k) == nil ? def : UserDefaults.standard.integer(forKey: k) }
        func bool(_ k: String, _ def: Bool) -> Bool { UserDefaults.standard.object(forKey: k) == nil ? def : UserDefaults.standard.bool(forKey: k) }
        focusMinutes = int("focusMinutes", 25)
        restMinutes = int("restMinutes", 5)
        keepAwake = bool("keepAwake", false)
        keepAliveItems = Self.load("keepAliveItems") ?? [.caffeinate]
        restItems = Self.load("restItems") ?? []
        shortcutsEnabled = bool("shortcutsEnabled", false)
        slackEnabled = bool("slackEnabled", false)
        // Move a token saved by an older version out of UserDefaults.
        if let old = UserDefaults.standard.string(forKey: "slackToken") {
            if !old.isEmpty { Keychain.set("slackToken", old) }
            UserDefaults.standard.removeObject(forKey: "slackToken")
        }
        slackToken = Keychain.get("slackToken") ?? ""
    }
}
