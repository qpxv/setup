// switches Terminal.app between "Clear Light" and "Clear Dark" when the system appearance changes.
// event-driven (kvo on the app appearance), so it does zero work while idle.
import AppKit

let lightProfile = "Clear Light"
let darkProfile = "Clear Dark"
let terminalBundleId = "com.apple.Terminal"

func isDarkMode() -> Bool {
    // AppleInterfaceStyle isn't written when appearance is set to "auto", so ask appkit instead
    NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
}

func logError(_ message: String) {
    FileHandle.standardError.write("terminal-theme-sync: \(message)\n".data(using: .utf8) ?? Data())
}

func applyProfile() {
    let profile = isDarkMode() ? darkProfile : lightProfile
    let isTerminalRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: terminalBundleId).isEmpty

    guard isTerminalRunning else {
        // terminal closed: just write its prefs so the next launch picks the right one
        CFPreferencesSetAppValue("Default Window Settings" as CFString, profile as CFString, terminalBundleId as CFString)
        CFPreferencesSetAppValue("Startup Window Settings" as CFString, profile as CFString, terminalBundleId as CFString)
        CFPreferencesAppSynchronize(terminalBundleId as CFString)
        return
    }

    // only retheme tabs that are on one of the two clear profiles, leave hand-picked ones alone
    let source = """
    tell application id "\(terminalBundleId)"
        set targetSettings to settings set "\(profile)"
        set default settings to targetSettings
        set startup settings to targetSettings
        repeat with w in windows
            repeat with t in tabs of w
                set currentName to name of current settings of t
                if currentName is "\(lightProfile)" or currentName is "\(darkProfile)" then
                    set current settings of t to targetSettings
                end if
            end repeat
        end repeat
    end tell
    """
    var error: NSDictionary?
    NSAppleScript(source: source)?.executeAndReturnError(&error)
    if let error {
        logError("applescript failed: \(error)")
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

let appearanceObservation = app.observe(\.effectiveAppearance, options: [.initial]) { _, _ in
    applyProfile()
}

// also catch terminal launching, in case it was opened before we got to it
NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didLaunchApplicationNotification,
    object: nil,
    queue: .main
) { note in
    let launchedApp = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
    if launchedApp?.bundleIdentifier == terminalBundleId {
        applyProfile()
    }
}

withExtendedLifetime(appearanceObservation) {
    app.run()
}
