param(
    [Parameter(Mandatory = $true)]
    [string[]]$Patterns,

    [string[]]$Paths = @("app", "routes", "resources/js", "database", "tests"),

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
    param([hashtable]$Store,[string]$File,[int]$Line,[string]$Text,[string]$Pattern)
    $display = Normalize-PathForDisplay $File
    if (-not $Store.ContainsKey($display)) { $Store[$display] = @{ Count = 0; Matches = @(); Patterns = @{} } }
    $Store[$display].Count++
    if (-not $Store[$display].Patterns.ContainsKey($Pattern)) { $Store[$display].Patterns[$Pattern] = 0 }
    $Store[$display].Patterns[$Pattern]++
    if ($Store[$display].Matches.Count -lt $MaxMatchesPerFile) {
        $Store[$display].Matches += @{ Line = $Line; Text = $Text.Trim(); Pattern = $Pattern }
    }
}

function Get-SymbolFromLine {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    $patterns = @(
        'class\s+([A-Za-z_][A-Za-z0-9_]*)',
        'interface\s+([A-Za-z_][A-Za-z0-9_]*)',
        'trait\s+([A-Za-z_][A-Za-z0-9_]*)',
        'enum\s+([A-Za-z_][A-Za-z0-9_]*)',
        'public\s+function\s+([A-Za-z_][A-Za-z0-9_]*)',
        'private\s+function\s+([A-Za-z_][A-Za-z0-9_]*)',
        'protected\s+function\s+([A-Za-z_][A-Za-z0-9_]*)',
        'function\s+([A-Za-z_][A-Za-z0-9_]*)',
        'const\s+([A-Za-z_][A-Za-z0-9_]*)\s*=',
        'const\s+([A-Za-z_][A-Za-z0-9_]*)\s*:',
        '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*\(',
        '^\s*const\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*\('
    )
    foreach ($pattern in $patterns) {
        $match = [regex]::Match($Text, $pattern)
        if ($match.Success -and $match.Groups.Count -gt 1) { return $match.Groups[1].Value }
    }
    return $null
}

function Get-RecommendedCommand {
    param([string]$Path,[array]$Matches)
    if (-not $Matches -or $Matches.Count -eq 0) { return $null }

    $usefulMatches = @($Matches | Where-Object {
        $_.Text -notmatch '^\s*use\s+' -and $_.Text -notmatch '^\s*import\s+' -and $_.Text -notmatch '^\s*namespace\s+'
    })
    if (-not $usefulMatches -or $usefulMatches.Count -eq 0) { $usefulMatches = $Matches }

    foreach ($match in $usefulMatches) {
        $symbol = Get-SymbolFromLine -Text $match.Text
        if ($symbol -and $Path -notmatch 'routes|migration|migrations|config|tests') {
            return ".\scripts\ai\read-symbol.ps1 -Path `"$Path`" -Symbol `"$symbol`" -Context 40"
        }
    }

    $firstMatch = $usefulMatches | Select-Object -First 1
    if (-not $firstMatch) { return $null }
    $context = if ($Path -match 'routes|migration|migrations|config|tests') { 20 } else { 30 }
    return ".\scripts\ai\read-window.ps1 -Path `"$Path`" -Line $($firstMatch.Line) -Context $context"
}

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

function Write-InvestigationProvenance {
    param([int]$ReturnedFiles,[int]$ReturnedMatches,[string[]]$Commands)
    $provenance = Get-ProvenanceContext
    $commandCount = @($Commands).Count
    $next = if ($commandCount -gt 0) { (@($Commands) | Select-Object -First 3) -join " | " } else { "narrow patterns/paths, then run one smallest read" }
    $reduced = ($store.Count -gt $ReturnedFiles -or $totalMatches -ge $MaxTotalMatches)
    Write-Host ""
    Write-Host "=== PROVENANCE ==="
    Write-Host "Repo: $($provenance.Repo)"
    Write-Host "Git: $($provenance.Git)"
    Write-Host "Tool: investigate.ps1"
    Write-Host "Scope: patterns=$($Patterns -join ', '); paths=$($Paths -join ', '); mode=$mode"
    Write-Host "Excluded: vendor, node_modules, storage, caches, .git, build outputs, min/maps"
    Write-Host "Considered: $($store.Count) matched files; $totalMatches sampled occurrences"
    Write-Host "Returned: $ReturnedFiles files; $ReturnedMatches preview matches; $commandCount commands"
    Write-Host "Reduction: limits files=$MaxFiles/per-file=$MaxMatchesPerFile/total=$MaxTotalMatches; compacted=$($reduced.ToString().ToLower())"
    Write-Host "Selection: ranked by occurrence count and useful non-import matches"
    Write-Host "Next: $next"
}

Write-Host ""
Write-Host "=== AI INVESTIGATION SUMMARY ==="
Write-Host "Patterns: $($Patterns -join ', ')"
Write-Host "Paths: $($Paths -join ', ')"
Write-Host "Max files: $MaxFiles"
Write-Host "Max matches per file: $MaxMatchesPerFile"
Write-Host ""

$store = @{}
$totalMatches = 0
$hasRipgrep = Get-Command rg -ErrorAction SilentlyContinue
$mode = if ($hasRipgrep) { "ripgrep fixed-strings" } else { "Select-String fallback" }

foreach ($pattern in $Patterns) {
    foreach ($path in $Paths) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        if ($totalMatches -ge $MaxTotalMatches) { break }

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
                -- $pattern $path 2>$null

            foreach ($line in $raw) {
                if ($totalMatches -ge $MaxTotalMatches) { break }
                $parts = $line -split ":", 3
                if ($parts.Count -lt 3) { continue }
                $lineNumber = 0
                [void][int]::TryParse($parts[1], [ref]$lineNumber)
                Add-Match -Store $store -File $parts[0] -Line $lineNumber -Text $parts[2] -Pattern $pattern
                $totalMatches++
            }
        } else {
            $files = Get-ChildItem -LiteralPath $path -Recurse -File -ErrorAction SilentlyContinue | Where-Object { -not (Is-ExcludedPath $_.FullName) }
            foreach ($file in $files) {
                if ($totalMatches -ge $MaxTotalMatches) { break }
                $matches = Select-String -LiteralPath $file.FullName -Pattern $pattern -SimpleMatch -ErrorAction SilentlyContinue
                foreach ($match in $matches) {
                    if ($totalMatches -ge $MaxTotalMatches) { break }
                    Add-Match -Store $store -File $match.Path -Line $match.LineNumber -Text $match.Line -Pattern $pattern
                    $totalMatches++
                }
            }
        }
    }
}

$files = @($store.GetEnumerator() | Sort-Object { $_.Value.Count } -Descending | Select-Object -First $MaxFiles)

Write-Host "Mode: $mode"
Write-Host "Files matched: $($store.Count)"
Write-Host "Occurrences sampled: $totalMatches"
if ($totalMatches -ge $MaxTotalMatches) { Write-Host "Sampling stopped at MaxTotalMatches=$MaxTotalMatches. Narrow patterns or paths if needed." -ForegroundColor Yellow }

Write-Host ""
Write-Host "=== TOP MATCHED FILES ==="
if (-not $files -or $files.Count -eq 0) {
    Write-Host "No matches."
    Write-Host ""
    Write-Host "=== GUIDANCE ==="
    Write-Host "Try fewer/broader patterns, or verify the affected domain from docs/context first."
    Write-InvestigationProvenance -ReturnedFiles 0 -ReturnedMatches 0 -Commands @()
    exit 0
}

foreach ($entry in $files) {
    $patternSummary = ($entry.Value.Patterns.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ", "
    "{0,4}  {1}  [{2}]" -f $entry.Value.Count, $entry.Key, $patternSummary
}

Write-Host ""
Write-Host "=== FIRST MATCHES BY FILE ==="
foreach ($entry in $files) {
    Write-Host ""
    Write-Host $entry.Key -ForegroundColor Cyan
    foreach ($match in $entry.Value.Matches) { "  {0,5}: {1}" -f $match.Line, $match.Text }
}

Write-Host ""
Write-Host "=== RECOMMENDED NEXT 3 COMMANDS ==="
$recommended = @()
foreach ($entry in $files | Select-Object -First 8) {
    if ($recommended.Count -ge 3) { break }
    $cmd = Get-RecommendedCommand -Path $entry.Key -Matches @($entry.Value.Matches)
    if ($cmd) { $recommended += $cmd }
}

if ($recommended.Count -eq 0) {
    Write-Host "No recommended commands could be generated."
    Write-Host "Use read-window.ps1 on the most relevant file/line from FIRST MATCHES BY FILE."
} else {
    foreach ($cmd in $recommended | Select-Object -First 3) { Write-Host $cmd }
}

Write-Host ""
Write-Host "=== AGENT INSTRUCTION ==="
Write-Host "Run at most the recommended next 3 commands."
Write-Host "Do not continue with more broad search.ps1 calls unless these results are insufficient."
Write-Host "If more than 8 total commands are needed, stop and summarize what is missing before continuing."

Write-Host ""
Write-Host "=== GUIDANCE ==="
Write-Host "Use this investigation summary instead of many small search commands."
Write-Host "Pick only the top 1-3 relevant files."
Write-Host "Prefer read-symbol.ps1 for classes, methods, services, controllers, policies, models, and React components."
Write-Host "Prefer read-window.ps1 for routes, migrations, config arrays, and nearby test assertions."
Write-Host "Do not continue exploratory search chains unless these results are insufficient."

$returnedMatches = @($files | ForEach-Object { $_.Value.Matches }).Count
Write-InvestigationProvenance -ReturnedFiles $files.Count -ReturnedMatches $returnedMatches -Commands @($recommended | Select-Object -First 3)
