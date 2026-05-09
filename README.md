# WideAwake

A macOS menu bar app that keeps your Mac awake while AI coding agents are running.

WideAwake monitors for **Claude Code**, **Claude Desktop**, and **Codex**. When it detects an agent, it prevents your Mac from sleeping so long-running tasks don't get interrupted. When all agents stop, sleep is re-enabled automatically.

## Features

- Prevents idle sleep while agents are running
- Optionally prevents lid-close sleep (so you can close your laptop and walk away)
- Hourly check-in when lid sleep is disabled, to make sure you still want to stay awake
- Starts at login by default
- Lives in the menu bar — no Dock icon

## Install

### Homebrew

```bash
brew install --cask shiv/tap/wideawake
```

### From Source

Requires Xcode Command Line Tools and macOS 13+.

```bash
git clone https://github.com/shiv/wideawake.git
cd wideawake
make install
```

## Usage

WideAwake appears as an icon in your menu bar: `moon.zzz` while monitoring, `eye` when actively keeping your Mac awake.

Click the icon to see detected agents and toggle preferences:

- **Prevent Lid Sleep** — keep awake even with the lid closed
- **Lid Sleep Automatically** — auto-enable lid sleep prevention when agents are detected
- **Activate Automatically** — skip the prompt and activate whenever agents are found
- **Start at Login** — enabled by default

## License

[MIT](LICENSE)
