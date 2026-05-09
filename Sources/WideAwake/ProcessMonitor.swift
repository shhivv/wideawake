import Dispatch
import Darwin

struct DetectedAgents: Equatable {
    var claudeCLI = false
    var codexCLI = false
    var opencodeCLI = false

    var anyCLI: Bool { claudeCLI || codexCLI || opencodeCLI }
    var any: Bool { anyCLI }

    var names: [String] {
        var result: [String] = []
        if claudeCLI { result.append("Claude Code") }
        if codexCLI { result.append("Codex") }
        if opencodeCLI { result.append("OpenCode") }
        return result
    }
}

final class ProcessMonitor {
    var onStateChange: ((DetectedAgents) -> Void)?
    private(set) var current = DetectedAgents()
    private var timer: DispatchSourceTimer?

    private static let maxPathSize: Int = 4 * Int(MAXPATHLEN)

    func startMonitoring() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .seconds(3))
        timer.setEventHandler { [weak self] in self?.poll() }
        timer.resume()
        self.timer = timer
    }

    func stopMonitoring() {
        timer?.cancel()
        timer = nil
    }

    private func poll() {
        var agents = DetectedAgents()

        let cliFound = findCLIProcesses(["claude", "codex", "opencode"])
        agents.claudeCLI = cliFound.contains("claude")
        agents.codexCLI = cliFound.contains("codex")
        agents.opencodeCLI = cliFound.contains("opencode")

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
