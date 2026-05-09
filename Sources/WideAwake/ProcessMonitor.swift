import AppKit
import Darwin

struct DetectedAgents: Equatable {
    var claudeCLI = false
    var claudeDesktop = false
    var codexCLI = false

    var anyCLI: Bool { claudeCLI || codexCLI }
    var any: Bool { claudeCLI || claudeDesktop || codexCLI }

    var names: [String] {
        var result: [String] = []
        if claudeCLI { result.append("Claude Code") }
        if claudeDesktop { result.append("Claude Desktop") }
        if codexCLI { result.append("Codex") }
        return result
    }
}

final class ProcessMonitor {
    var onStateChange: ((DetectedAgents) -> Void)?
    private(set) var current = DetectedAgents()
    private var timer: DispatchSourceTimer?

    private static let claudeDesktopBundleID = "com.anthropic.claudefordesktop"
    private static let maxPathSize: Int = 4 * Int(MAXPATHLEN)

    func startMonitoring() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            self, selector: #selector(appEvent),
            name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        center.addObserver(
            self, selector: #selector(appEvent),
            name: NSWorkspace.didTerminateApplicationNotification, object: nil)

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .seconds(3))
        timer.setEventHandler { [weak self] in self?.poll() }
        timer.resume()
        self.timer = timer
    }

    func stopMonitoring() {
        timer?.cancel()
        timer = nil
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func appEvent(_ notification: Notification) {
        poll()
    }

    private func poll() {
        var agents = DetectedAgents()

        agents.claudeDesktop = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == Self.claudeDesktopBundleID
        }

        let cliFound = findCLIProcesses(["claude", "codex"])
        agents.claudeCLI = cliFound.contains("claude")
        agents.codexCLI = cliFound.contains("codex")

        guard agents != current else { return }
        current = agents
        onStateChange?(agents)
    }

    private func findCLIProcesses(_ names: [String]) -> Set<String> {
        var found = Set<String>()

        var size = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard size > 0 else { return found }

        let count = Int(size) / MemoryLayout<pid_t>.size
        var pids = [pid_t](repeating: 0, count: count)
        size = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, size)
        let actual = Int(size) / MemoryLayout<pid_t>.size

        let buf = UnsafeMutablePointer<CChar>.allocate(capacity: Self.maxPathSize)
        defer { buf.deallocate() }

        for i in 0..<actual where pids[i] > 0 {
            let len = proc_pidpath(pids[i], buf, UInt32(Self.maxPathSize))
            guard len > 0 else { continue }
            let path = String(cString: buf)
            for name in names {
                if path.hasSuffix("/\(name)") || path.contains("/\(name)/") {
                    found.insert(name)
                }
            }
            if found.count == names.count { break }
        }

        return found
    }
}
