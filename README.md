# cmux-conjure

> One command to conjure your terminal-first agentic workspace in [cmux](https://cmux.com).

`conjure` builds a full IDE-like layout in cmux using its **control socket API** — no AppleScript, no keystroke timing, reproducible every run.

```
┌──────────────┬───────────────────────┐
│              │  [lazygit] [helix]    │  ← right-top pane, two tabs
│   claude     ├───────────────────────┤
│              │  dev terminal         │  ← right-bottom pane
└──────────────┴───────────────────────┘
```

## Prerequisites

- macOS
- [Homebrew](https://brew.sh)
- [cmux.app](https://cmux.com) installed in `/Applications`

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/ITZSHOAIB/cmux-conjure/main/install.sh | bash
```

The interactive installer (powered by [gum](https://github.com/charmbracelet/gum)) will ask you to choose:

| Prompt | Options |
|---|---|
| Theme | Catppuccin Mocha · TokyoNight Storm · Gruvbox Dark Hard · Kanagawa Wave |
| Font size | 13 · **14** · 15 |
| AI agent | **claude** · opencode · codex · none |
| Editor tab | **helix** · nvim · vim |

It installs and configures: `lazygit`, `delta`, `helix`, `yazi`, `starship`, `zoxide`, `bat`, `fd`, `ripgrep` — and writes curated configs for all of them.

## Usage

```bash
conjure ~/my-project
```

Open a new shell after installing, then run `conjure` from anywhere.

## What opens

| Pane | Tool | Notes |
|---|---|---|
| Left | `claude` (or your chosen agent) | Cursor lands here after launch |
| Right-top tab 1 | `lazygit` | Themed delta diffs, Nerd Font icons |
| Right-top tab 2 | `hx .` (Helix) | Catppuccin Mocha, LSP inlay hints |
| Right-bottom | dev terminal | `cd`'d into the project, ready for your server |

## Overrides

Override any pane command without reinstalling:

```bash
CONJURE_MAIN_CMD="opencode"  conjure ~/my-project
CONJURE_LG_CMD="tig"         conjure ~/my-project
CONJURE_HX_CMD="nvim ."      conjure ~/my-project
CONJURE_DEV_CMD="yarn dev"   conjure ~/my-project
```

## Config templates

All configs live in `templates/` and use `{{PLACEHOLDER}}` substitution. Edit them before running `install.sh` to customise defaults:

| File | Written to |
|---|---|
| `ghostty.config` | `~/.config/ghostty/config` |
| `helix.toml` | `~/.config/helix/config.toml` |
| `lazygit.yml` | `~/Library/Application Support/lazygit/config.yml` |
| `yazi.toml` | `~/.config/yazi/yazi.toml` |
| `starship.toml` | `~/.config/starship.toml` |
| `gitconfig-delta.ini` | merged into `~/.gitconfig` |
| `cmux-settings.jsonc` | `~/.config/cmux/cmux.json` |

## Non-interactive install (CI / scripting)

```bash
CONJURE_NON_INTERACTIVE=1 \
CONJURE_THEME="Catppuccin Mocha" \
CONJURE_FONT_SIZE=14 \
CONJURE_AGENT=claude \
CONJURE_EDITOR=helix \
bash install.sh
```

## Development

Tests use [bats-core](https://github.com/bats-core/bats-core). A mock `cmux` binary in `test/bin/` intercepts all socket calls so tests run without a live cmux instance.

```bash
brew install bats-core
bats test/
```

## License

MIT © [Sohab Sk](https://github.com/ITZSHOAIB)
