# Powerline "pill" status line for Claude Code - PowerShell port.
# Requires a Nerd Font (the pill caps are Powerline glyphs) and a
# truecolor-capable terminal such as Windows Terminal.
#
# Every non-ASCII character is emitted via [char] so this file stays
# pure ASCII: Windows PowerShell 5.1 reads BOM-less scripts in the
# system ANSI codepage and would mangle UTF-8 literals.

$ESC = [char]27
$CapL = [char]0xE0B6       # Powerline left half-circle cap
$CapR = [char]0xE0B4       # Powerline right half-circle cap
$Dot = [char]0xB7          # middle dot separator
$Hourglass = [char]0x23F3  # hourglass-with-flowing-sand emoji

# -- Pill styling ------------------------------------------------------
# A pill = rounded left cap + background-coloured text + rounded right
# cap. Caps are drawn with foreground = the pill's background colour,
# on the default terminal background.
# Colours are SGR parameter strings: "2;R;G;B" (truecolor) or "5;N" (256).
$PILL_BG = '2;66;70;90'    # #42465a - tuned for a dark terminal theme
$PILL_TEXT = '5;250'       # light grey text inside pills
$WARN_BG = '5;208'         # orange background
$WARN_FG = '5;235'         # dark text for contrast on orange
$DANGER_BG = '5;196'       # red background
$DANGER_FG = '5;231'       # white text for contrast on red

function Pill($bg, $fg, $text) {
    "${ESC}[38;${bg}m${CapL}${ESC}[48;${bg}m${ESC}[38;${fg}m${text}${ESC}[0m${ESC}[38;${bg}m${CapR}${ESC}[0m"
}

# -- Input parsing -----------------------------------------------------
# Claude Code pipes a JSON object via stdin on each update.
try {
    $data = $input | Out-String | ConvertFrom-Json
} catch {
    $data = $null
}

# Bad/missing input -> one plain pill: never a blank bar, never a
# half-rendered line
if ($null -eq $data) {
    Write-Host (Pill $PILL_BG $PILL_TEXT 'claude')
    exit 0
}

# Model: first word of the display name, lowercased (e.g. "opus")
$model = ("$($data.model.display_name)" -split ' ')[0].ToLower()
if ([string]::IsNullOrEmpty($model)) { $model = 'unknown' }

# Effort level appended when present (e.g. "opus . high")
$effort = $data.effort.level
if (-not [string]::IsNullOrEmpty($effort)) { $model = "$model $Dot $effort" }

$used = $data.context_window.used_percentage
if ($null -eq $used) { $used = 0 }
$pct = [int][math]::Round($used)
$window = $data.context_window.context_window_size
if ($null -eq $window) { $window = 200000 }

# Dynamic thresholds based on context window size
if ($window -ge 1000000) {
    # 1M window: orange above 15%, red above 35%
    $warn = 15
    $danger = 35
} else {
    # 200K window: orange above 30%, red above 60%
    $warn = 30
    $danger = 60
}

# Context pill background: quiet by default, orange/red as usage climbs
if ($pct -le $warn) {
    $ctx_bg = $PILL_BG; $ctx_fg = $PILL_TEXT
} elseif ($pct -le $danger) {
    $ctx_bg = $WARN_BG; $ctx_fg = $WARN_FG
} else {
    $ctx_bg = $DANGER_BG; $ctx_fg = $DANGER_FG
}

# Rate limit pill: hourglass + 5h-window usage + time until the window
# resets (fields only present for subscribers after first API response)
$rate_str = ''
$rate_bg = $PILL_BG
$rate_fg = $PILL_TEXT
$rpct = $data.rate_limits.five_hour.used_percentage
if ($null -ne $rpct) {
    $rpct = [int][math]::Round($rpct)
    # Same colours as the context pill: orange at 50%, red at 75%
    if ($rpct -ge 75) {
        $rate_bg = $DANGER_BG; $rate_fg = $DANGER_FG
    } elseif ($rpct -ge 50) {
        $rate_bg = $WARN_BG; $rate_fg = $WARN_FG
    }
    # No space after the hourglass - its double-width cell is the gap
    $rate_str = "${Hourglass}${rpct}%"
    $resets = $data.rate_limits.five_hour.resets_at
    if ($null -ne $resets) {
        $rem = [long]$resets - [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        if ($rem -gt 0) {
            $h = [math]::Floor($rem / 3600)
            $m = [math]::Floor(($rem % 3600) / 60)
            if ($h -gt 0) {
                $rate_str += " $Dot ${h}h$('{0:d2}' -f [int]$m)"
            } else {
                $rate_str += " $Dot ${m}m"
            }
        }
    }
}

# Estimated API cost pill: what the session would cost at API rates
# (informational on a subscription - never an actual charge). Cost is
# converted to integer cents and formatted with integer arithmetic so
# the output stays invariant under comma-decimal cultures.
$cost_str = ''
$cost = $data.cost.total_cost_usd
if ($null -ne $cost) {
    $cents = [long][math]::Round([double]$cost * 100)
    $cost_str = '${0}.{1:d2}' -f [long][math]::Floor($cents / 100), [int]($cents % 100)
}

# Layout: four uniform pills - model . context % . rate limits . est. cost
$out = "$(Pill $PILL_BG $PILL_TEXT $model)  $(Pill $ctx_bg $ctx_fg "${pct}%")"
if ($rate_str) { $out += "  $(Pill $rate_bg $rate_fg $rate_str)" }
if ($cost_str) { $out += "  $(Pill $PILL_BG $PILL_TEXT $cost_str)" }
Write-Host $out
