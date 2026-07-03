param([int]$MaxLines = 120)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Continue"

function Get-ProvenanceContext {
    $context = @{ Repo = "unknown"; Git = "unknown@unknown" }
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $repo = & git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and $repo) { $context.Repo = ($repo | Select-Object -First 1) }
        $branch = & git branch --show-current 2>$null
        $head = & git rev-parse --short HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and $head) {
            if (-not $branch) { $branch = "detached" }
            $context.Git = "$branch@$head"
        }
    }
    return $context
}

$gitAvailable = [bool](Get-Command git -ErrorAction SilentlyContinue)
if ($gitAvailable) {
    $statusLines = @(git status --short 2>&1 | ForEach-Object { $_.ToString() })
    $statLines = @(git diff --stat 2>&1 | ForEach-Object { $_.ToString() })
    $statExit = $LASTEXITCODE
    $changedFileLines = @(git diff --name-only 2>&1 | ForEach-Object { $_.ToString() })
} else {
    $statusLines = @("Git unavailable.")
    $statLines = @("Git unavailable.")
    $changedFileLines = @("Git unavailable.")
    $statExit = 1
}

$shownStatus = @($statusLines | Select-Object -First $MaxLines)
$shownStat = @($statLines | Select-Object -First $MaxLines)
$shownChangedFiles = @($changedFileLines | Select-Object -First $MaxLines)

Write-Host ""
Write-Host "=== GIT STATUS SHORT ==="
$shownStatus

Write-Host ""
Write-Host "=== DIFF STAT ==="
$shownStat

Write-Host ""
Write-Host "=== CHANGED FILES ==="
$shownChangedFiles

$provenance = Get-ProvenanceContext
$statAvailable = ($statExit -eq 0)
$consideredLines = $statusLines.Count + $statLines.Count + $changedFileLines.Count
$returnedLines = $shownStatus.Count + $shownStat.Count + $shownChangedFiles.Count
$truncated = ($statusLines.Count -gt $MaxLines -or $statLines.Count -gt $MaxLines -or $changedFileLines.Count -gt $MaxLines)
Write-Host ""
Write-Host "=== PROVENANCE ==="
Write-Host "Repo: $($provenance.Repo)"
Write-Host "Git: $($provenance.Git)"
Write-Host "Tool: diff-summary.ps1"
Write-Host "Scope: working-tree status/stat/name summary; max-lines=$MaxLines"
Write-Host "Excluded: file-level diff contents"
Write-Host "Considered: $($statusLines.Count) changed status entries; $consideredLines summary lines"
Write-Host "Returned: $returnedLines summary lines; stat-available=$($statAvailable.ToString().ToLower())"
Write-Host "Reduction: per-section limit=$MaxLines; compacted=$($truncated.ToString().ToLower())"
Write-Host "Selection: status/stat summary before file-level diff"
Write-Host "Next: use diff-file.ps1 for exact files"
