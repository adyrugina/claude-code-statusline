# claude-code-statusline

A custom status line for [Claude Code](https://claude.ai/claude-code) that shows the active model and context window usage with color-coded indicators.

## What it looks like

```
Claude Opus 4.6 | context 42%
```

The context percentage changes color based on usage:

- **Green** (0-30%) -- plenty of room
- **Yellow** (31-60%) -- getting there
- **Red** (61-100%) -- running low, consider compacting

## Prerequisites

- [Claude Code](https://claude.ai/claude-code) CLI installed
- [`jq`](https://jqlang.github.io/jq/) -- a command-line JSON processor
  - macOS: `brew install jq`
  - Linux: `apt install jq` or `dnf install jq`

## Installation

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

## How it works

Claude Code pipes a JSON object to the status line script via stdin on each update. The JSON contains:

- `model.display_name` -- the active model (e.g., "Claude Opus 4.6")
- `context_window.context_window_size` -- total context window in tokens
- `context_window.current_usage` -- current token usage breakdown

The script uses `jq` to parse this JSON, calculates what percentage of the context window is in use, and outputs an ANSI color-coded string.

For more details, see the [Claude Code statusLine documentation](https://code.claude.com/docs/en/statusline).

## Customization

The color thresholds and output format are easy to adjust in `statusline.sh`:

- Change the percentage breakpoints in the `get_color()` function (default: 30% and 60%)
- Modify the `echo` line at the bottom to change what gets displayed
- Swap the ANSI color codes at the top for your preferred colors

## License

[MIT](LICENSE)
