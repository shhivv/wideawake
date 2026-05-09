# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
swift build                 # debug build
swift build -c release      # release build
swift run                   # run directly (no .app bundle, for development)
make app                    # build .app bundle with code signing
make install                # install to /Applications
make zip                    # create distributable zip + print sha256
make clean                  # clean build artifacts and app bundle
```

## Architecture

macOS menu bar utility (no dock icon, `LSUIElement`) that prevents idle sleep while AI coding agents are running. Built with Swift Package Manager + AppKit.

### Core Components

- **ProcessMonitor** — Detects running AI agents via `libproc` (`proc_pidpath`) polling every 3s for CLI tools (`claude`, `codex`). Must use `proc_pidpath` because Claude Code rewrites its process name to the version string at runtime, making `pgrep` unreliable.
- **SleepManager** — Wraps `IOPMAssertionCreateWithName` (IOKit) to create/release `NoIdleSleepAssertion`. Assertions auto-release if the app crashes.
- **AppDelegate** — Orchestrates everything: NSStatusItem (eye icon), menu, alert on first detection, auto-activate preference via UserDefaults.

### Flow

1. ProcessMonitor polls for CLI agents every 3s
2. On state change → AppDelegate either auto-activates (if preference set) or shows NSAlert asking the user
3. SleepManager creates IOPMAssertion when activated, releases when all agents stop
4. Menu bar icon toggles between `eye` (monitoring) and `eye.fill` (active)

### Distribution

Install script (`install.sh`) downloads the latest release zip and copies to `/Applications`. GitHub Actions workflow (`.github/workflows/release.yml`) builds and uploads `.zip` on version tags (`v*`).
