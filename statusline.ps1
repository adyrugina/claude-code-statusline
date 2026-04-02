$data = $input | Out-String | ConvertFrom-Json
$model = $data.model.display_name
$used = $data.context_window.used_percentage
if ($null -eq $used) { $used = 0 }
$pct = [math]::Round($used)
$ESC = [char]27

if ($pct -le 30) {
    $pct_str = "$pct%"
} elseif ($pct -le 60) {
    $pct_str = "${ESC}[38;5;208m$pct%${ESC}[0m"
} else {
    $pct_str = "${ESC}[31m$pct%${ESC}[0m"
}
Write-Host "$model | context: $pct_str"
