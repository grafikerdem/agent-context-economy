param(
    [Parameter(Mandatory = $true)]
    [string]$Pattern,

    [Parameter(Mandatory = $true)]
    [string]$Path,

    [int]$MaxFiles = 15,
    [int]$MaxMatchesPerFile = 3,
    [int]$MaxTotalMatches = 80
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Continue"

function Normalize-PathForDisplay {
    param([string]$Path)
    if (-not $Path) { return "" }
    $root = (Get-Location).Path -replace '\\','/'
    $normalized = $Path -replace '\\','/'
    if ($normalized.StartsWith($root)) { $normalized = $normalized.Substring($root.Length).TrimStart('/') }
    return $normalized
}

function Is-ExcludedPath {
    param([string]$Path)
    $normalized = $Path -replace '\\','/'
    $excluded = @('/vendor/','/node_modules/','/storage/','/bootstrap/cache/','/.git/','/public/build/','/coverage/','/dist/')
    foreach ($item in $excluded) { if ($normalized -like "*$item*") { return $true } }
    return $false
}

function Add-Match {
    param([hashtable]$Store,[string]$File,[int]$Line,[string]$Text)
    $display = Normalize-PathForDisplay $File
    if (-not $Store.ContainsKey($display)) { $Store[$display] = @{ Count = 0; Matches = @() } }
    $Store[$display].Count++
    if ($Store[$display].Matches.Count -lt $MaxMatchesPerFile) {
        $Store[$display].Matches += @{ Line = $Line; Text = $Text.Trim() }
    }
}

Write-Host ""
Write-Host "=== AI SEARCH SUMMARY ==="
Write-Host "Pattern: $Pattern"
Write-Host "Path: $Path"

if (-not (Test-Path -LiteralPath $Path)) {
    Write-Host "ERROR: Path not found: $Path" -ForegroundColor Red
    exit 1
}

$store = @{}
$totalMatches = 0
$hasRipgrep = Get-Command rg -ErrorAction SilentlyContinue
$mode = if ($hasRipgrep) { "ripgrep fixed-strings" } else { "Select-String fallback" }
Write-Host "Mode: $mode"

if ($hasRipgrep) {
    $raw = & rg -n --hidden `
        --glob '!vendor/**' `
        --glob '!node_modules/**' `
        --glob '!storage/**' `
        --glob '!bootstrap/cache/**' `
        --glob '!.git/**' `
        --glob '!public/build/**' `
        --glob '!coverage/**' `
        --glob '!dist/**' `
        --glob '!*.min.js' `
        --glob '!*.map' `
        --fixed-strings `
        -- $Pattern $Path 2>$null

    foreach ($line in $raw) {
        if ($totalMatches -ge $MaxTotalMatches) { break }
        $parts = $line -split ":", 3
        if ($parts.Count -lt 3) { continue }
        $lineNumber = 0
        [void][int]::TryParse($parts[1], [ref]$lineNumber)
        Add-Match -Store $store -File $parts[0] -Line $lineNumber -Text $parts[2]
        $totalMatches++
    }
} else {
    Write-Host "ripgrep not found. Falling back to Select-String with exclusions." -ForegroundColor Yellow
    $files = Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue | Where-Object { -not (Is-ExcludedPath $_.FullName) }
    foreach ($file in $files) {
        if ($totalMatches -ge $MaxTotalMatches) { break }
        $matches = Select-String -LiteralPath $file.FullName -Pattern $Pattern -SimpleMatch -ErrorAction SilentlyContinue
        foreach ($match in $matches) {
            if ($totalMatches -ge $MaxTotalMatches) { break }
            Add-Match -Store $store -File $match.Path -Line $match.LineNumber -Text $match.Line
            $totalMatches++
        }
    }
}

$files = @($store.GetEnumerator() | Sort-Object { $_.Value.Count } -Descending | Select-Object -First $MaxFiles)

Write-Host ""
Write-Host "Files matched: $($store.Count)"
Write-Host "Occurrences sampled: $totalMatches"
if ($totalMatches -ge $MaxTotalMatches) { Write-Host "Sampling stopped at MaxTotalMatches=$MaxTotalMatches. Narrow the path or pattern if needed." -ForegroundColor Yellow }

Write-Host ""
Write-Host "=== TOP FILES ==="
if (-not $files -or $files.Count -eq 0) {
    Write-Host "No matches."
    Write-Host ""
    Write-Host "=== RECOMMENDED NEXT STEP ==="
    Write-Host "Do not repeat the same search unchanged. Try a more exact symbol or a narrower likely folder."
    exit 0
}

foreach ($entry in $files) { "{0,4}  {1}" -f $entry.Value.Count, $entry.Key }

Write-Host ""
Write-Host "=== FIRST MATCHES BY FILE ==="
foreach ($entry in $files) {
    Write-Host ""
    Write-Host $entry.Key -ForegroundColor Cyan
    foreach ($match in $entry.Value.Matches) { "  {0,5}: {1}" -f $match.Line, $match.Text }
}

Write-Host ""
Write-Host "=== RECOMMENDED NEXT STEP ==="
Write-Host "Pick one relevant file/line and use:"
Write-Host '.\scripts\ai\read-window.ps1 -Path "<path>" -Line <line> -Context 30'
Write-Host "If the target is a named class/function/component/method, prefer:"
Write-Host '.\scripts\ai\read-symbol.ps1 -Path "<path>" -Symbol "<symbol>" -Context 40'
Write-Host "Do not inspect all matches."
