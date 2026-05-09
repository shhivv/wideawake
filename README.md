# WideAwake

A macOS menu bar app that keeps your Mac awake while AI coding agents are running.

WideAwake monitors for **Claude Code** and **Codex**. When it detects an agent, it prevents your Mac from sleeping so long-running tasks don't get interrupted. When all agents stop, sleep is re-enabled automatically.

## Features

- Prevents idle sleep while agents are running
- Optionally prevents lid-close sleep (so you can close your laptop and walk away)
- Hourly check-in when lid sleep is disabled, to make sure you still want to stay awake
- Starts at login by default
- Lives in the menu bar — no Dock icon

## Install

```bash
curl -sL https://raw.githubusercontent.com/shhivv/wideawake/master/install.sh | bash
```

### From Source

Requires Xcode Command Line Tools and macOS 13+.

```bash
git clone https://github.com/shiv/wideawake.git
cd wideawake
make install
```

## License

[MIT](LICENSE)
