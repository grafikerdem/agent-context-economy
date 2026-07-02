param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [int]$MaxLines = 200
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $Path)) {
    Write-Host "ERROR: File not found: $Path" -ForegroundColor Red
    exit 1
}

$content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
$lines = @($content -split "`r?`n")
$showCount = [Math]::Min($MaxLines, $lines.Count)

Write-Host ""
Write-Host "=== UTF-8 TEXT READ ==="
Write-Host "File: $Path"
Write-Host "Total lines: $($lines.Count)"
Write-Host "Showing lines: 1-$showCount"
Write-Host ""

$lines | Select-Object -First $MaxLines

if ($lines.Count -gt $MaxLines) {
    Write-Host ""
    Write-Host "=== TRUNCATED ===" -ForegroundColor Yellow
    Write-Host "Output truncated. Rerun with a higher -MaxLines only if needed."
}
