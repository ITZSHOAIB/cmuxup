# cmuxup

> One command to set up your terminal-first agentic coding workspace in [cmux](https://cmux.com).

`cmuxup` turns [cmux](https://cmux.com) into a focused, IDE-like workspace for coding with AI agents — your agent, your git TUI, and your editor laid out side by side, themed and ready. It builds the layout through cmux's **control socket API**, so it's reproducible every run — no AppleScript, no keystroke timing.

```
┌──────────────┬───────────────────────┐
│              │  [lazygit] [editor]   │  ← right-top pane, two tabs
│   claude     ├───────────────────────┤
│              │  dev terminal         │  ← right-bottom pane
└──────────────┴───────────────────────┘
```

## Why

Agentic coding in the terminal usually means juggling windows: the agent here, git there, an editor somewhere else. `cmuxup` gives you one consistent layout, one command to open it, and sensible defaults so you can just start working.

- **One command** — `cmuxup ~/my-project` and the whole workspace opens
- **No bloat** — a small, focused set of tools that actually earn their place
- **No magic** — plain bash, readable configs you own, nothing hidden
- **Reproducible** — driven by the cmux socket API, identical every time

## Prerequisites

- macOS
- [Homebrew](https://brew.sh)
- [cmux.app](https://cmux.com) installed in `/Applications`

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/ITZSHOAIB/cmuxup/main/install.sh | bash
```

The installer is pure bash — no extra dependencies, no TUI framework. It walks you through a few quick choices with simple arrow-key menus:

| Prompt | Options |
|---|---|
| Theme | **Catppuccin Mocha** · TokyoNight Storm · Gruvbox Dark Hard · Kanagawa Wave |
| Font size | 13 · **14** · 15 |
| AI agent | **claude** · opencode · codex · none |
| Lazygit | install the git TUI? (**yes**/no) |
| Editor | **helix** · nvim · vim · none |

Existing config files are backed up to `<file>.bak` before anything is overwritten.

## What gets installed

**Core** (always — the foundation the workspace relies on):

| Tool | Role |
|---|---|
| [`delta`](https://github.com/dandavison/delta) | Syntax-highlighted git diffs, in the terminal and in lazygit |
| [`ripgrep`](https://github.com/BurntSushi/ripgrep) | Fast search — powers the editor's project-wide search |
| [`fd`](https://github.com/sharkdp/fd) | Fast file finding — powers the editor's file picker |
| [`zoxide`](https://github.com/ajeetdsouza/zoxide) | Smart `cd` — jump to directories by name |
| [`fzf`](https://github.com/junegunn/fzf) | Fuzzy finder — history (`ctrl-r`), files (`ctrl-t`), `cd` (`alt-c`) |
| [`bat`](https://github.com/sharkdp/bat) | Syntax-highlighted file preview — powers fzf previews |

**Optional** (your choice during install):

| Tool | Role |
|---|---|
| [`lazygit`](https://github.com/jesseduffield/lazygit) | Git TUI in the right-top pane, with themed delta diffs |
| [`helix`](https://helix-editor.com) / `nvim` / `vim` | Editor tab in the right-top pane |

Each tool gets a curated, theme-matched config written to its standard location.

## Usage

```bash
cmuxup ~/my-project
```

Open a new shell after installing, then run `cmuxup` from anywhere.

| Pane | Tool | Notes |
|---|---|---|
| Left | `claude` (or your chosen agent) | Cursor lands here after launch |
| Right-top tab 1 | `lazygit` | Themed delta diffs, Nerd Font icons |
| Right-top tab 2 | `hx .` (your editor) | Theme-matched, LSP inlay hints |
| Right-bottom | dev terminal | `cd`'d into the project, ready for your dev server |

The layout adapts to what you installed — skip lazygit or the editor and the right-top pane collapses to a single tab (or a plain terminal).

## Overrides

Override any pane command per-invocation, without reinstalling:

```bash
CMUXUP_MAIN_CMD="opencode"  cmuxup ~/my-project   # different agent
CMUXUP_LG_CMD="tig"         cmuxup ~/my-project   # different git tool
CMUXUP_HX_CMD="nvim ."      cmuxup ~/my-project   # different editor
CMUXUP_DEV_CMD="yarn dev"   cmuxup ~/my-project   # auto-run dev server
CMUXUP_LG_CMD="" CMUXUP_HX_CMD="" cmuxup .        # bare agent + terminal
```

## Config templates

All configs live in `templates/` and use `{{PLACEHOLDER}}` substitution. Edit them before running `install.sh` to change the defaults:

| File | Written to |
|---|---|
| `ghostty.config` | `~/.config/ghostty/config` |
| `helix.toml` | `~/.config/helix/config.toml` |
| `lazygit.yml` | `~/Library/Application Support/lazygit/config.yml` |
| `gitconfig-delta.ini` | merged into `~/.gitconfig` |
| `cmux-settings.jsonc` | `~/.config/cmux/cmux.json` |

## Non-interactive install (CI / scripting)

```bash
CMUXUP_NON_INTERACTIVE=1 \
CMUXUP_THEME="Catppuccin Mocha" \
CMUXUP_FONT_SIZE=14 \
CMUXUP_AGENT=claude \
CMUXUP_LAZYGIT=1 \
CMUXUP_EDITOR=helix \
bash install.sh
```

Add `--dry-run` to preview every action without changing anything.

## Development

Tests use [bats-core](https://github.com/bats-core/bats-core). A mock `cmux` binary in `test/bin/` intercepts all socket calls, so the suite runs without a live cmux instance.

```bash
brew install bats-core
bats test/
```

The installer's non-interactive path is fully exercised by the suite; the interactive arrow-key menus are pure bash with no external dependencies.

## License

MIT © [Sohab Sk](https://github.com/ITZSHOAIB)
