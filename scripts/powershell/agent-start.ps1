param(
    [string]$Root = ".",
    [int]$MaxMapLines = 12
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    Write-Host "ERROR: Repository root not found: $Root" -ForegroundColor Red
    exit 1
}

$rootPath = (Resolve-Path -LiteralPath $Root).Path
$contextDirectory = Join-Path $rootPath ".agent-context"
$mapPath = Join-Path $contextDirectory "repo-map.md"
$statePath = Join-Path $contextDirectory "session-state.json"

Write-Host "=== ACE STARTUP BRIEFING ==="
Write-Host "Repository: $rootPath"
Write-Host ""

Write-Host "Continuity:"
if (Test-Path -LiteralPath $statePath -PathType Leaf) {
    try {
        $state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
        Write-Host "  Task: $(if ($state.task) { $state.task } else { '(not set)' })"
        $files = @($state.files)
        $searches = @($state.searches)
        Write-Host "  Relevant files: $($files.Count)"
        foreach ($file in ($files | Select-Object -First 5)) { Write-Host "    - $file" }
        Write-Host "  Useful searches: $($searches.Count)"
        foreach ($search in ($searches | Select-Object -First 5)) { Write-Host "    - $search" }
    } catch {
        Write-Host "  Session state is unreadable; clear or recreate it." -ForegroundColor Yellow
    }
} else {
    Write-Host "  No session state. Use session-state.ps1 set-task -Value <task>."
}

Write-Host ""
Write-Host "Repository map:"
if (Test-Path -LiteralPath $mapPath -PathType Leaf) {
    $mapLines = @(Get-Content -LiteralPath $mapPath -Encoding UTF8 | Where-Object {
        $_ -match '^(Files counted:|## |\- `)'
    } | Select-Object -First $MaxMapLines)
    foreach ($line in $mapLines) { Write-Host "  $line" }
    if ($mapLines.Count -eq 0) { Write-Host "  Present: $mapPath" }
} else {
    Write-Host "  No map. Run repo-map.ps1 once for structural orientation."
}

Write-Host ""
Write-Host "Preferred workflow:"
Write-Host "  repo-map -> investigate -> read-symbol -> read-window -> run-compact"
Write-Host "Skip known steps; use bounded raw exploration when a helper cannot express the query."
