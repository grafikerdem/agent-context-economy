param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [int]$MaxLines = 220
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "=== DIFF FILE ==="
Write-Host "File: $Path"
Write-Host ""

$output = git diff -- $Path 2>&1
$lines = @($output | ForEach-Object { $_.ToString() })
$shown = @($lines | Select-Object -First $MaxLines)
$shown

Write-Host ""
Write-Host "=== RESULT ==="
Write-Host "Raw lines: $($lines.Count)"
Write-Host "Shown lines: $($shown.Count)"
if ($lines.Count -gt $MaxLines) { Write-Host "Diff truncated. Use a narrower file or increase -MaxLines if needed." -ForegroundColor Yellow }
