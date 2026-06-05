#!/bin/sh
input=$(cat)

# ── Pill styling ──────────────────────────────────────────────────────
# A pill = rounded left cap + background-coloured padded text + rounded
# right cap. Caps are Nerd Font Powerline half-circles, emitted as octal
# UTF-8 so no editor can strip them:
#   \356\202\266 = U+E0B6 (left cap)   \356\202\264 = U+E0B4 (right cap)
# Caps are drawn with foreground = the pill's background colour, on the
# default terminal background. The spaces around the text while the
# background colour is active are the padding.
# Colours are SGR parameter strings: "2;R;G;B" (truecolor) or "5;N" (256).
# Truecolor is safe here - Warp sets COLORTERM=truecolor.
PILL_BG="2;66;70;90"   # #42465a - terminal bg (#3a3d4d) lifted half a step, hue kept
PILL_TEXT="5;250"      # light grey text inside pills
WARN_BG="5;208"        # orange background
WARN_FG="5;235"        # dark text for contrast on orange
DANGER_BG="5;196"      # red background
DANGER_FG="5;231"      # white text for contrast on red

# pill <bg-colour> <fg-colour> <text>
pill() {
  printf '\033[38;%sm\356\202\266\033[48;%sm\033[38;%sm%s\033[0m\033[38;%sm\356\202\264\033[0m' \
    "$1" "$1" "$2" "$3" "$1"
}

# ── Input parsing ─────────────────────────────────────────────────────
# One jq pass emits ready-to-eval shell assignments. Two jq helpers make
# every field independently fault-tolerant, so a single weird value can
# never collapse the whole bar (it used to: an empty display_name or a
# string-typed used_percentage threw, and you got a bare "claude" pill):
#   clean : strips C0 control bytes (U+0001-U+001F) from strings, so a
#           model name carrying raw escape sequences can't retitle your
#           window, clear the screen, or smuggle a hyperlink
#   num   : coerces anything (null, number, numeric string) to a number,
#           defaulting to 0 - `round` never sees a non-number again
# String fields go through @sh, which shell-quotes them, so the eval below
# is injection-safe; numeric fields are bare integers and need no quoting.
# All numeric work stays in jq (round, the reset countdown via `now`) to
# dodge locale-dependent shell printf rounding.
assignments=$(printf '%s' "$input" | jq -r '
  def clean: if type == "string" then gsub("[[:cntrl:]]"; "") else . end;
  def num:   (tostring | tonumber? // 0);
  "model="  + ((.model.display_name // "" | clean | split(" ")[0] // ""
               | if . == "" then "unknown" else . end | ascii_downcase) | @sh) + " " +
  "effort=" + ((.effort.level // "" | clean) | @sh) + " " +
  "pct="    + (.context_window.used_percentage | num | round | tostring) + " " +
  "window=" + (.context_window.context_window_size // 200000 | num | tostring) + " " +
  "rpct="   + (.rate_limits.five_hour.used_percentage
               | if . == null then "\"\"" else (num | round | tostring) end) + " " +
  "rem="    + (.rate_limits.five_hour.resets_at
               | if . == null then "\"\"" else ((num) - now | floor | tostring) end)
' 2>/dev/null)

# Empty result = malformed input or no jq → one plain pill: never a blank
# bar, never stderr spam, never a half-rendered line
if [ -z "$assignments" ]; then
  pill "$PILL_BG" "$PILL_TEXT" "claude"
  printf '\n'
  exit 0
fi

# Declare defaults first: documents the contract, keeps the script sane if a
# field is ever missing, and lets shellcheck see the vars the eval assigns.
# Values are jq-quoted (strings via @sh, numbers as bare integers), so the
# eval only ever assigns data - it can't execute it.
model='' effort='' pct=0 window=200000 rpct='' rem=''
eval "$assignments"

# Keep the braces: bash 3.2 mis-parses $var glued to a multibyte char
# (lead byte absorbed into the variable name) if the space is ever removed
[ -n "$effort" ] && model="${model} · ${effort}"

# Dynamic thresholds based on context window size
if [ "$window" -ge 1000000 ]; then
  # 1M window: orange above 15%, red above 35%
  warn=15
  danger=35
else
  # 200K window: orange above 30%, red above 60%
  warn=30
  danger=60
fi

# Context pill background: quiet by default, orange/red as usage climbs
if [ "$pct" -le "$warn" ]; then
  ctx_bg=$PILL_BG
  ctx_fg=$PILL_TEXT
elif [ "$pct" -le "$danger" ]; then
  ctx_bg=$WARN_BG
  ctx_fg=$WARN_FG
else
  ctx_bg=$DANGER_BG
  ctx_fg=$DANGER_FG
fi

# Rate limit pill: hourglass + 5h-window usage + time until the window
# resets (fields only present for subscribers after first API response)
rate_str=""
rate_bg=$PILL_BG
rate_fg=$PILL_TEXT
if [ -n "$rpct" ]; then
  # Same colours as the context pill: orange at 50%, red at 75%
  if [ "$rpct" -ge 75 ]; then
    rate_bg=$DANGER_BG; rate_fg=$DANGER_FG
  elif [ "$rpct" -ge 50 ]; then
    rate_bg=$WARN_BG; rate_fg=$WARN_FG
  fi
  # \342\217\263 = U+23F3 hourglass-with-flowing-sand emoji, octal UTF-8
  # (no space after it - the emoji's double-width cell provides the gap)
  rate_str=$(printf '\342\217\263%s%%' "$rpct")
  if [ -n "$rem" ] && [ "$rem" -gt 0 ]; then
    h=$(( rem / 3600 ))
    m=$(( (rem % 3600) / 60 ))
    if [ "$h" -gt 0 ]; then
      rate_str="${rate_str} · ${h}h$(printf '%02d' "$m")"
    else
      rate_str="${rate_str} · ${m}m"
    fi
  fi
fi

# Layout: three uniform pills - model · context % · rate limits
out="$(pill "$PILL_BG" "$PILL_TEXT" "$model")  $(pill "$ctx_bg" "$ctx_fg" "${pct}%")"
[ -n "$rate_str" ] && out="$out  $(pill "$rate_bg" "$rate_fg" "$rate_str")"
printf '%s\n' "$out"
