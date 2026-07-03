param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [int]$MaxLines = 220
)

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

Write-Host ""
Write-Host "=== DIFF FILE ==="
Write-Host "File: $Path"
Write-Host ""

$output = if (Get-Command git -ErrorAction SilentlyContinue) { git diff -- $Path 2>&1 } else { "Git unavailable." }
$lines = @($output | ForEach-Object { $_.ToString() })
$shown = @($lines | Select-Object -First $MaxLines)
$shown

Write-Host ""
Write-Host "=== RESULT ==="
Write-Host "Raw lines: $($lines.Count)"
Write-Host "Shown lines: $($shown.Count)"
if ($lines.Count -gt $MaxLines) { Write-Host "Diff truncated. Use a narrower file or increase -MaxLines if needed." -ForegroundColor Yellow }

$provenance = Get-ProvenanceContext
$truncated = ($lines.Count -gt $MaxLines)
Write-Host ""
Write-Host "=== PROVENANCE ==="
Write-Host "Repo: $($provenance.Repo)"
Write-Host "Git: $($provenance.Git)"
Write-Host "Tool: diff-file.ps1"
Write-Host "Scope: path=$Path; max-lines=$MaxLines"
Write-Host "Excluded: all other files"
Write-Host "Considered: $($lines.Count) diff lines"
Write-Host "Returned: $($shown.Count) diff lines"
Write-Host "Reduction: $($lines.Count) -> $($shown.Count) lines; compacted=$($truncated.ToString().ToLower())"
Write-Host "Selection: single-file diff only"
Write-Host "Next: inspect related source/test or run targeted validation"
