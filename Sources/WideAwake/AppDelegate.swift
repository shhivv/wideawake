import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let sleepManager = SleepManager()
    private let processMonitor = ProcessMonitor()
    private var hasPrompted = false
    private var checkInTimer: DispatchSourceTimer?

    private var autoActivate: Bool {
        get { UserDefaults.standard.bool(forKey: "autoActivate") }
        set { UserDefaults.standard.set(newValue, forKey: "autoActivate") }
    }

    private var autoLidSleep: Bool {
        get { UserDefaults.standard.bool(forKey: "autoLidSleep") }
        set { UserDefaults.standard.set(newValue, forKey: "autoLidSleep") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()
        rebuildMenu()

        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            try? SMAppService.mainApp.register()
        }

        processMonitor.onStateChange = { [weak self] agents in
            self?.handleAgentChange(agents)
        }
        processMonitor.startMonitoring()
    }

    func applicationWillTerminate(_ notification: Notification) {
        sleepManager.allowSleep()
        sleepManager.enableLidSleep()
        stopCheckInTimer()
        processMonitor.stopMonitoring()
    }

    // MARK: - State Machine

    private func handleAgentChange(_ agents: DetectedAgents) {
        if agents.anyCLI {
            if autoActivate {
                activate()
            } else if !sleepManager.isActive && !hasPrompted {
                promptUser(agents)
            }
            if autoLidSleep && !sleepManager.lidSleepDisabled {
                sleepManager.disableLidSleep()
                if sleepManager.lidSleepDisabled { startCheckInTimer() }
            }
        } else if !agents.anyCLI {
            deactivate()
            if sleepManager.lidSleepDisabled {
                sleepManager.enableLidSleep()
                stopCheckInTimer()
            }
            hasPrompted = false
        }
        updateIcon()
        rebuildMenu()
    }

    private func promptUser(_ agents: DetectedAgents) {
        hasPrompted = true
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "AI Agents Running"
        alert.informativeText =
            "\(agents.names.joined(separator: ", ")) detected. Keep your Mac awake?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Keep Awake")
        alert.addButton(withTitle: "Not Now")
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Always activate automatically"

        if alert.runModal() == .alertFirstButtonReturn {
            if alert.suppressionButton?.state == .on {
                autoActivate = true
            }
            activate()
            rebuildMenu()
        }
    }

    // MARK: - Sleep Control

    private func activate() {
        guard !sleepManager.isActive else { return }
        sleepManager.preventSleep()
        updateIcon()
    }

    private func deactivate() {
        if sleepManager.isActive {
            sleepManager.allowSleep()
        }
        updateIcon()
    }

    // MARK: - Hourly Check-In

    private func startCheckInTimer() {
        stopCheckInTimer()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 3600, repeating: 3600)
        timer.setEventHandler { [weak self] in self?.showCheckIn() }
        timer.resume()
        checkInTimer = timer
    }

    private func stopCheckInTimer() {
        checkInTimer?.cancel()
        checkInTimer = nil
    }

    private func showCheckIn() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "WideAwake Still Active"
        alert.informativeText = "Sleep prevention has been on for a while. Are your agents still running?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Keep Going")
        alert.addButton(withTitle: "Turn Off")

        if alert.runModal() == .alertSecondButtonReturn {
            deactivate()
            if sleepManager.lidSleepDisabled {
                sleepManager.enableLidSleep()
            }
            rebuildMenu()
        }
    }

    // MARK: - UI

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let preventingSleep = sleepManager.isActive || sleepManager.lidSleepDisabled
        button.image = NSImage(
            systemSymbolName: preventingSleep ? "eye" : "moon.zzz",
            accessibilityDescription: "WideAwake"
        )
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let agents = processMonitor.current

        let status = NSMenuItem()
        if sleepManager.isActive && sleepManager.lidSleepDisabled {
            status.title = "Keeping Mac Awake (lid safe)"
        } else if sleepManager.isActive {
            status.title = "Keeping Mac Awake"
        } else if sleepManager.lidSleepDisabled {
            status.title = "Lid Sleep Disabled"
        } else if agents.any {
            status.title = "Agents Detected"
        } else {
            status.title = "Monitoring for AI Agents"
        }
        status.isEnabled = false
        menu.addItem(status)

        for name in agents.names {
            let item = NSMenuItem()
            item.title = "\u{25CF} \(name)"
            item.indentationLevel = 1
            item.isEnabled = false
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        // Idle Sleep section
        let idleHeader = NSMenuItem()
        idleHeader.title = "Idle Sleep"
        idleHeader.isEnabled = false
        menu.addItem(idleHeader)

        let keepAwake = NSMenuItem(
            title: "Keep Awake",
            action: #selector(toggleIdleSleep), keyEquivalent: "")
        keepAwake.target = self
        keepAwake.indentationLevel = 1
        keepAwake.state = sleepManager.isActive ? .on : .off
        menu.addItem(keepAwake)

        let autoIdle = NSMenuItem(
            title: "When Agents Detected",
            action: #selector(toggleAuto), keyEquivalent: "")
        autoIdle.target = self
        autoIdle.indentationLevel = 1
        autoIdle.state = autoActivate ? .on : .off
        menu.addItem(autoIdle)

        // Lid Sleep section
        let lidHeader = NSMenuItem()
        lidHeader.title = "Lid Sleep"
        lidHeader.isEnabled = false
        menu.addItem(lidHeader)

        let lid = NSMenuItem(
            title: "Prevent Lid Sleep",
            action: #selector(toggleLidSleep), keyEquivalent: "")
        lid.target = self
        lid.indentationLevel = 1
        lid.state = sleepManager.lidSleepDisabled ? .on : .off
        menu.addItem(lid)

        let autoLid = NSMenuItem(
            title: "When Agents Detected",
            action: #selector(toggleAutoLidSleep), keyEquivalent: "")
        autoLid.target = self
        autoLid.indentationLevel = 1
        autoLid.state = autoLidSleep ? .on : .off
        menu.addItem(autoLid)

        menu.addItem(NSMenuItem.separator())

        let login = NSMenuItem(
            title: "Start at Login",
            action: #selector(toggleLoginItem), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(
            title: "Quit WideAwake",
            action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func toggleIdleSleep() {
        if sleepManager.isActive {
            deactivate()
        } else {
            activate()
        }
        rebuildMenu()
    }

    @objc private func toggleLidSleep() {
        if sleepManager.lidSleepDisabled {
            sleepManager.enableLidSleep()
            stopCheckInTimer()
        } else {
            sleepManager.disableLidSleep()
            if sleepManager.lidSleepDisabled { startCheckInTimer() }
        }
        updateIcon()
        rebuildMenu()
    }

    @objc private func toggleAutoLidSleep() {
        autoLidSleep.toggle()
        if autoLidSleep && processMonitor.current.anyCLI && !sleepManager.lidSleepDisabled {
            sleepManager.disableLidSleep()
        } else if !autoLidSleep && sleepManager.lidSleepDisabled {
            sleepManager.enableLidSleep()
        }
        updateIcon()
        rebuildMenu()
    }

    @objc private func toggleAuto() {
        autoActivate.toggle()
        if autoActivate && processMonitor.current.anyCLI && !sleepManager.isActive {
            activate()
        } else if !autoActivate && sleepManager.isActive {
            deactivate()
        }
        rebuildMenu()
    }

    @objc private func toggleLoginItem() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {}
        rebuildMenu()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
