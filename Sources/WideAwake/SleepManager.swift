import AppKit
import IOKit
import IOKit.pwr_mgt

final class SleepManager {
    private var assertionID: IOPMAssertionID = 0
    private(set) var isActive = false
    private(set) var lidSleepDisabled = false

    private static let lidSleepKey = "didDisableLidSleep"
    private static let sudoersPath = "/etc/sudoers.d/wideawake"

    init() {
        if UserDefaults.standard.bool(forKey: Self.lidSleepKey) {
            enableLidSleep()
        }
    }

    // MARK: - Idle Sleep (IOPMAssertion, no privilege needed)

    @discardableResult
    func preventSleep() -> Bool {
        guard !isActive else { return true }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoIdleSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "WideAwake: AI agents are running" as CFString,
            &assertionID
        )
        isActive = (result == kIOReturnSuccess)
        return isActive
    }

    func allowSleep() {
        guard isActive else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isActive = false
    }

    // MARK: - Lid Sleep (pmset, one-time sudoers setup)

    func disableLidSleep() {
        guard !lidSleepDisabled else { return }
        if runPmsetPrivileged("disablesleep 1") {
            lidSleepDisabled = true
            UserDefaults.standard.set(true, forKey: Self.lidSleepKey)
        }
    }

    func enableLidSleep() {
        guard lidSleepDisabled || UserDefaults.standard.bool(forKey: Self.lidSleepKey) else { return }
        if runPmsetPrivileged("disablesleep 0") {
            lidSleepDisabled = false
            UserDefaults.standard.set(false, forKey: Self.lidSleepKey)
        }
    }

    // MARK: - Privileged Execution

    private func runPmsetPrivileged(_ args: String) -> Bool {
        ensureSudoersRule()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", "/usr/bin/pmset", "-a"] + args.split(separator: " ").map(String.init)
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func ensureSudoersRule() {
        guard !FileManager.default.fileExists(atPath: Self.sudoersPath) else { return }

        let rule = "%admin ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1\n"
        let tmpPath = NSTemporaryDirectory() + "wideawake-sudoers"
        guard FileManager.default.createFile(atPath: tmpPath, contents: rule.data(using: .utf8)) else {
            return
        }
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }

        let cmd = "cp '\(tmpPath)' \(Self.sudoersPath) && chmod 0440 \(Self.sudoersPath)"
        guard let script = NSAppleScript(source:
            "do shell script \"\(cmd)\" with administrator privileges"
        ) else { return }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
    }

    deinit {
        allowSleep()
        if lidSleepDisabled { enableLidSleep() }
    }
}
