param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Pattern,

    [int]$MaxMatches = 40,

    [switch]$Regex
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Continue"

function Fail($Message) { Write-Host "ERROR: $Message" -ForegroundColor Red; exit 1 }
if (-not (Test-Path -LiteralPath $Path)) { Fail "File not found: $Path" }

Write-Host ""
Write-Host "=== FILE SEARCH ==="
Write-Host "File: $Path"
Write-Host "Pattern: $Pattern"
Write-Host "Mode: $(if ($Regex) { 'regex' } else { 'literal SimpleMatch' })"
Write-Host ""

if ($Regex) {
    $matches = @(Select-String -LiteralPath $Path -Pattern $Pattern -ErrorAction Stop)
} else {
    $matches = @(Select-String -LiteralPath $Path -Pattern $Pattern -SimpleMatch -ErrorAction Stop)
}

if (-not $matches -or $matches.Count -eq 0) {
    Write-Host "No matches."
    Write-Host ""
    Write-Host "=== GUIDANCE ==="
    Write-Host "Do not repeat the same search unchanged. Try a more exact symbol, route, field, permission key, or nearby file."
    exit 0
}

Write-Host "Matches: $($matches.Count)"
Write-Host ""
Write-Host "=== MATCH LINES ==="

$shown = @($matches | Select-Object -First $MaxMatches)
foreach ($m in $shown) { "{0,5}: {1}" -f $m.LineNumber, $m.Line.Trim() }

if ($matches.Count -gt $MaxMatches) {
    Write-Host ""
    Write-Host "=== COMPACTED ===" -ForegroundColor Yellow
    Write-Host "Found $($matches.Count) matches. Showing first $MaxMatches. Use a more specific pattern."
}

Write-Host ""
Write-Host "=== RECOMMENDED NEXT STEP ==="
Write-Host "Read the smallest relevant window:"
Write-Host '.\scripts\ai\read-window.ps1 -Path "<path>" -Line <line> -Context 30'
Write-Host "If this is a class/function/component/hook/type, prefer:"
Write-Host '.\scripts\ai\read-symbol.ps1 -Path "<path>" -Symbol "<symbol>" -Context 40'
