import Foundation
import Dispatch
import Darwin

struct DetectedAgents: Equatable {
    var claudeCLI = false
    var codexCLI = false
    var opencodeCLI = false
    var hermesCLI = false

    var anyCLI: Bool { claudeCLI || codexCLI || opencodeCLI || hermesCLI }
    var any: Bool { anyCLI }

    var names: [String] {
        var result: [String] = []
        if claudeCLI { result.append("Claude Code") }
        if codexCLI { result.append("Codex") }
        if opencodeCLI { result.append("OpenCode") }
        if hermesCLI { result.append("Hermes") }
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

        let cliFound = findCLIProcesses(["claude", "codex", "opencode", "hermes"])
        agents.claudeCLI = cliFound.contains("claude")
        agents.codexCLI = cliFound.contains("codex")
        agents.opencodeCLI = cliFound.contains("opencode")
        agents.hermesCLI = cliFound.contains("hermes")

        guard agents != current else { return }
        current = agents
        onStateChange?(agents)
    }

    private static let pythonPattern = "/python"

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
            for name in names where !found.contains(name) {
                if path.hasSuffix("/\(name)") || path.contains("/\(name)/") {
                    found.insert(name)
                } else if path.contains(Self.pythonPattern) {
                    if matchesProcessArgs(pid: pids[i], name: name) {
                        found.insert(name)
                    }
                }
            }
            if found.count == names.count { break }
        }

        return found
    }

    private func matchesProcessArgs(pid: pid_t, name: String) -> Bool {
        var mib = [CTL_KERN, KERN_PROCARGS2, Int32(pid)]
        var argmax = 0
        guard sysctl(&mib, 3, nil, &argmax, nil, 0) == 0, argmax > 0 else { return false }

        var buf = [UInt8](repeating: 0, count: argmax)
        var bufSize = argmax
        guard sysctl(&mib, 3, &buf, &bufSize, nil, 0) == 0, bufSize > 4 else { return false }

        let argc = buf.withUnsafeBytes { $0.load(as: Int32.self) }
        let suffix = "/\(name)"

        var argIndex: Int32 = -1 // -1 = exec path, then 0..<argc
        var start: Int? = nil
        for j in 4..<bufSize {
            if buf[j] == 0 {
                if let s = start {
                    let arg = String(bytes: buf[s..<j], encoding: .utf8) ?? ""
                    if arg.hasSuffix(suffix) { return true }
                    argIndex += 1
                    if argIndex >= argc { break }
                    start = nil
                }
            } else if start == nil {
                start = j
            }
        }
        return false
    }
}
