$data = $input | Out-String | ConvertFrom-Json
$model = ($data.model.display_name) -replace '\(1M context\)', '(1M)'
$used = $data.context_window.used_percentage
if ($null -eq $used) { $used = 0 }
$pct = [math]::Round($used)
$window = $data.context_window.context_window_size
if ($null -eq $window) { $window = 200000 }
$ESC = [char]27

# Dynamic thresholds based on context window size
if ($window -ge 1000000) {
    $warn = 15
    $danger = 35
} else {
    $warn = 30
    $danger = 60
}

if ($pct -le $warn) {
    $pct_str = "$pct%"
} elseif ($pct -le $danger) {
    $pct_str = "${ESC}[38;5;208m$pct%${ESC}[0m"
} else {
    $pct_str = "${ESC}[31m$pct%${ESC}[0m"
}

# Rate limit fields (available after first API response)
$dim = "${ESC}[38;5;240m"
$reset_dim = "${ESC}[0m"
$rate_str = ""

$five_pct = $data.rate_limits.five_hour.used_percentage
if ($null -ne $five_pct) {
    $five_val = [math]::Round($five_pct)
    $rate_str += " ${dim}| now: ${five_val}%${reset_dim}"
}

$week_pct = $data.rate_limits.seven_day.used_percentage
if ($null -ne $week_pct) {
    $week_val = [math]::Round($week_pct)
    $rate_str += " ${dim}| week: ${week_val}%${reset_dim}"
}

# Folder path (second line) — show current directory relative to user profile
$cwd = (Get-Location).Path
$home_path = $env:USERPROFILE
if ($cwd.StartsWith($home_path)) {
    $folder_path = $cwd.Substring($home_path.Length)
} else {
    $folder_path = $cwd
}
if ([string]::IsNullOrEmpty($folder_path)) { $folder_path = "~" }

Write-Host "$model | context: $pct_str$rate_str"
Write-Host "${dim}${folder_path}${reset_dim}"
