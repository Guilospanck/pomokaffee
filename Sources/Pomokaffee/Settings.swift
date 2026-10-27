import Foundation

/// User preferences, persisted in UserDefaults.
final class Settings: ObservableObject {
    static let shared = Settings()
    private let d = UserDefaults.standard

    @Published var focusMinutes: Int { didSet { d.set(focusMinutes, forKey: "focusMinutes") } }
    @Published var restMinutes: Int { didSet { d.set(restMinutes, forKey: "restMinutes") } }
    @Published var keepAwake: Bool { didSet { d.set(keepAwake, forKey: "keepAwake") } }
    @Published var cleanupEnabled: Bool { didSet { d.set(cleanupEnabled, forKey: "cleanupEnabled") } }
    @Published var cleanupCommand: String { didSet { d.set(cleanupCommand, forKey: "cleanupCommand") } }
    /// One shell command per line, run at the start of every rest.
    @Published var restScripts: String { didSet { d.set(restScripts, forKey: "restScripts") } }
    @Published var shortcutsEnabled: Bool { didSet { d.set(shortcutsEnabled, forKey: "shortcutsEnabled") } }
    @Published var shortcutOn: String { didSet { d.set(shortcutOn, forKey: "shortcutOn") } }
    @Published var shortcutOff: String { didSet { d.set(shortcutOff, forKey: "shortcutOff") } }
    @Published var slackEnabled: Bool { didSet { d.set(slackEnabled, forKey: "slackEnabled") } }
    @Published var slackToken: String { didSet { d.set(slackToken, forKey: "slackToken") } }

    private init() {
        func int(_ k: String, _ def: Int) -> Int { UserDefaults.standard.object(forKey: k) == nil ? def : UserDefaults.standard.integer(forKey: k) }
        func bool(_ k: String, _ def: Bool) -> Bool { UserDefaults.standard.object(forKey: k) == nil ? def : UserDefaults.standard.bool(forKey: k) }
        func str(_ k: String, _ def: String) -> String { UserDefaults.standard.string(forKey: k) ?? def }
        focusMinutes = int("focusMinutes", 25)
        restMinutes = int("restMinutes", 5)
        keepAwake = bool("keepAwake", false)
        cleanupEnabled = bool("cleanupEnabled", true)
        cleanupCommand = str("cleanupCommand", "cleanup-caches --deep")
        restScripts = str("restScripts", "")
        shortcutsEnabled = bool("shortcutsEnabled", false)
        shortcutOn = str("shortcutOn", "Pomokaffee Focus On")
        shortcutOff = str("shortcutOff", "Pomokaffee Focus Off")
        slackEnabled = bool("slackEnabled", false)
        slackToken = str("slackToken", "")
    }
}
