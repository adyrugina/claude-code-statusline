# claude-code-statusline

A custom status line for [Claude Code](https://claude.ai/claude-code) that shows the active model and context window usage with color-coded indicators. Works on macOS, Linux, and Windows.

## What it looks like

![Status line preview showing color-coded context usage](statusline-preview.png)

The context percentage changes color based on usage:

- **Default** (0-30%) -- smart zone
- **Orange** (31-60%) -- getting into the dumb zone
- **Red** (61-100%) -- really dumb zone, consider compacting

## macOS / Linux

### Prerequisites

- [Claude Code](https://claude.ai/claude-code) CLI installed
- [`jq`](https://jqlang.github.io/jq/) -- a command-line JSON processor
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
       "command": "~/.claude/statusline.sh"
     }
   }
   ```

   If you already have a `settings.json`, just add the `"statusLine"` key to your existing object.

5. Restart Claude Code. The status line will appear at the bottom of the terminal.

## Windows

### Prerequisites

- [Claude Code](https://claude.ai/claude-code) CLI installed
- PowerShell (included with Windows)

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
       "command": "powershell -NoProfile -File C:/Users/YOUR-USERNAME/.claude/statusline.ps1"
     }
   }
   ```

   Replace `YOUR-USERNAME` with your Windows username. If you already have a `settings.json`, just add the `"statusLine"` key to your existing object.

4. Restart Claude Code. The status line will appear at the bottom of the terminal.

## How it works

Claude Code pipes a JSON object to the status line script via stdin on each update. The JSON contains:

- `model.display_name` -- the active model (e.g., "Opus 4.6 (1M context)")
- `context_window.used_percentage` -- what percentage of the context window is in use

The script parses this JSON and outputs an ANSI color-coded string.

For more details, see the [Claude Code statusLine documentation](https://docs.anthropic.com/en/docs/claude-code/settings#status-bar).

## Customization

The color thresholds and output format are easy to adjust:

- Change the percentage breakpoints in the `if/elif/else` block (default: 30% and 60%)
- Modify the output format line to change what gets displayed
- Swap the ANSI color codes for your preferred colors

## License

[MIT](LICENSE)
