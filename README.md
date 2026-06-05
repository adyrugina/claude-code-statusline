# claude-code-statusline

A Powerline-style "pill" status line for [Claude Code](https://claude.ai/claude-code): active model and effort level, context window usage with dynamic colour thresholds, and rate limit usage with a live countdown to the next reset. Works on macOS, Linux, and Windows.

## What it looks like

<img width="642" height="63" alt="image" src="https://github.com/user-attachments/assets/1c9a4ee8-ace1-4885-b6f2-876d08ccbb63" />


| Pill | Content |
|---|---|
| **Model** | Model name, lowercased (`opus`, `sonnet`), plus the effort level when set (`opus · high`) |
| **Context** | Percentage of the context window in use — quiet grey by default, orange/red as it climbs |
| **Rate limit** | ⏳ 5-hour window usage and time until the window resets (`1h29`, `45m`) — appears once rate limit data is available |

If the script receives bad input or `jq` is missing, it degrades to a single plain `claude` pill instead of a broken or blank bar.

### Colour thresholds

**Context pill** — thresholds adapt to the context window size, because 1M-context models degrade earlier in absolute token terms:

| | Quiet | Orange | Red |
|---|---|---|---|
| **200K models** | 0–30% | 31–60% | 61%+ |
| **1M models** | 0–15% | 16–35% | 36%+ |

**Rate limit pill** — orange at 50% of the 5-hour window, red at 75%.

## Requirements

- A font with **Powerline glyphs** — the pill caps are U+E0B6 / U+E0B4 half-circles. Any [Nerd Font](https://www.nerdfonts.com/) works; some terminals (e.g. Warp) bundle these glyphs out of the box. Without them the caps render as missing-glyph boxes.
- A **truecolor-capable terminal** (Warp, iTerm2, WezTerm, Windows Terminal, most modern emulators) — the base pill uses 24-bit colour.
- The base pill colour (`#42465a`) is tuned for a **dark theme**. On a light theme, change `PILL_BG` (see [Customization](#customization)).

## macOS / Linux

### Prerequisites

- [Claude Code](https://claude.ai/claude-code) CLI installed
- [`jq`](https://jqlang.github.io/jq/) — a command-line JSON processor
  - macOS: `brew install jq`
  - Linux: `apt install jq` or `dnf install jq`

### Installation

1. Clone this repo:

   ```bash
   git clone https://github.com/adyrugina/claude-code-statusline.git
   ```

2. Copy the script to your Claude Code config directory:

   ```bash
   cp claude-code-statusline/statusline.sh ~/.claude/statusline.sh
   ```

3. Make it executable:

   ```bash
   chmod +x ~/.claude/statusline.sh
   ```

4. Add the status line configuration to `~/.claude/settings.json`:

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "sh ~/.claude/statusline.sh",
       "refreshInterval": 60
     }
   }

   If you already have a `settings.json`, just add the `"statusLine"` key to your existing object. `refreshInterval` (in seconds) re-runs the script once a minute so the reset countdown keeps ticking while the session is idle — without it, the status line only updates on message events.

5. Restart Claude Code. The status line will appear at the bottom of the terminal.

## Windows

### Prerequisites

- [Claude Code](https://claude.ai/claude-code) CLI installed
- PowerShell (included with Windows)
- Windows Terminal (or another truecolor terminal) with a Nerd Font configured

### Installation

1. Clone this repo:

   ```powershell
   git clone https://github.com/adyrugina/claude-code-statusline.git
   ```

2. Copy the script to your Claude Code config directory:

   ```powershell
   Copy-Item claude-code-statusline\statusline.ps1 $env:USERPROFILE\.claude\statusline.ps1
   ```

3. Add the status line configuration to `~/.claude/settings.json`:

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "powershell -NoProfile -File C:/Users/YOUR-USERNAME/.claude/statusline.ps1",
       "refreshInterval": 60
     }
   }
   ```

   Replace `YOUR-USERNAME` with your Windows username. If you already have a `settings.json`, just add the `"statusLine"` key to your existing object.

4. Restart Claude Code. The status line will appear at the bottom of the terminal.

> The PowerShell port mirrors the shell script one-to-one but has had less real-world testing than the macOS/Linux version — issues and PRs welcome.

## How it works

Claude Code pipes a JSON object to the status line script via stdin on each update. The script uses these fields:

- `model.display_name` — the active model (e.g. `"Opus 4.8 (1M context)"`); the first word is shown, lowercased
- `effort.level` — the configured effort level (e.g. `"high"`), appended to the model pill when present
- `context_window.used_percentage` — how much of the context window is in use
- `context_window.context_window_size` — total window size in tokens, used to pick the colour thresholds
- `rate_limits.five_hour.used_percentage` — 5-hour rolling rate limit usage
- `rate_limits.five_hour.resets_at` — epoch timestamp of the next rate limit reset, turned into the countdown

The shell version does all parsing and arithmetic in a **single `jq` pass** — including rounding (avoids `printf %.0f`, which breaks under comma-decimal locales) and the reset countdown (via `jq`'s `now`). The pill caps are emitted as octal UTF-8 escapes so no editor or copy-paste step can strip them.

For more details, see the [Claude Code status line documentation](https://code.claude.com/docs/en/statusline).

## Customization

All knobs are at the top of each script:

- **Colours** — SGR parameter strings: `"2;R;G;B"` (truecolor) or `"5;N"` (256-colour). `PILL_BG` is the base pill background; pick something a half-step lighter than your terminal background so pills read as raised
- **Context thresholds** — `warn` / `danger` values per window size
- **Rate limit thresholds** — the `50` / `75` comparisons in the rate pill section
- **Drop the rate pill** — remove the rate limit section if you don't need it

## License

[MIT](LICENSE)
