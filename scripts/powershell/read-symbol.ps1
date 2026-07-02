param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Symbol,

    [int]$Context = 30,

    [int]$MaxOutputLines = 220
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

function Fail($Message) { Write-Host "ERROR: $Message" -ForegroundColor Red; exit 1 }
if (-not (Test-Path -LiteralPath $Path)) { Fail "File not found: $Path" }

function Normalize-Symbol {
    param([string]$Value)
    $v = $Value.Trim()
    $v = $v -replace '^class\s+', ''
    $v = $v -replace '^function\s+', ''
    $v = $v -replace '^const\s+', ''
    $v = $v -replace '^interface\s+', ''
    $v = $v -replace '^type\s+', ''
    $v = $v -replace '^enum\s+', ''
    $v = $v -replace '\s*\(.*$', ''
    return $v.Trim()
}

function Count-Char {
    param([AllowEmptyString()][string]$Text,[char]$Char)
    if ([string]::IsNullOrEmpty($Text)) { return 0 }
    return ($Text.ToCharArray() | Where-Object { $_ -eq $Char }).Count
}

function Detect-BlockEnd {
    param([string[]]$Lines,[int]$StartLine)
    $total = $Lines.Count
    $startIndex = $StartLine - 1
    $braceDepth = 0
    $seenOpen = $false
    for ($i = $startIndex; $i -lt $total; $i++) {
        $line = $Lines[$i]
        $open = Count-Char -Text $line -Char '{'
        $close = Count-Char -Text $line -Char '}'
        if ($open -gt 0) { $seenOpen = $true }
        $braceDepth += $open
        $braceDepth -= $close
        if ($seenOpen -and $braceDepth -le 0) { return ($i + 1) }
        if (-not $seenOpen -and $i -gt $startIndex -and [string]::IsNullOrWhiteSpace($line)) { return ($i + 1) }
    }
    return $total
}

$lines = @(Get-Content -LiteralPath $Path -Encoding UTF8)
$total = $lines.Count
$normalizedSymbol = Normalize-Symbol $Symbol

Write-Host ""
Write-Host "=== SYMBOL NAVIGATOR ==="
Write-Host "File: $Path"
Write-Host "Requested symbol: $Symbol"
Write-Host "Normalized symbol: $normalizedSymbol"
Write-Host "Total lines: $total"

$regexSymbol = [regex]::Escape($normalizedSymbol)
$definitionPatterns = @(
    "class\s+$regexSymbol\b",
    "interface\s+$regexSymbol\b",
    "trait\s+$regexSymbol\b",
    "enum\s+$regexSymbol\b",
    "function\s+$regexSymbol\b",
    "(public|private|protected)\s+function\s+$regexSymbol\b",
    "const\s+$regexSymbol\s*=",
    "const\s+$regexSymbol\s*:",
    "\b$regexSymbol\s*=\s*\(",
    "\b$regexSymbol\s*=\s*async\s*\(",
    "\b$regexSymbol\s*:\s*"
)

$candidates = @()
for ($i = 1; $i -le $total; $i++) {
    $text = $lines[$i - 1]
    $isDef = $false
    foreach ($p in $definitionPatterns) {
        if ($text -match $p) { $isDef = $true; break }
    }
    if ($isDef) {
        $candidates += @{ Line = $i; Text = $text.Trim(); Kind = 'DEF' }
    }
}

if ($candidates.Count -eq 0) {
    for ($i = 1; $i -le $total; $i++) {
        $text = $lines[$i - 1]
        if ($text -match $regexSymbol) {
            $candidates += @{ Line = $i; Text = $text.Trim(); Kind = 'REF' }
        }
    }
}

Write-Host ""
Write-Host "=== MATCH CANDIDATES ==="
if ($candidates.Count -eq 0) {
    Write-Host "No symbol candidates found."
    Write-Host "Try find-in-file.ps1 with a more exact keyword."
    exit 0
}

foreach ($c in ($candidates | Select-Object -First 20)) {
    "{0,5} [{1}] {2}" -f $c.Line, $c.Kind, $c.Text
}

$selected = $candidates | Where-Object { $_.Kind -eq 'DEF' } | Select-Object -First 1
if (-not $selected) { $selected = $candidates | Select-Object -First 1 }

$blockStart = $selected.Line
$blockEnd = if ($selected.Kind -eq 'DEF') { Detect-BlockEnd -Lines $lines -StartLine $blockStart } else { $selected.Line }

$start = [Math]::Max(1, $blockStart - $Context)
$end = [Math]::Min($total, $blockEnd + $Context)

if (($end - $start + 1) -gt $MaxOutputLines) {
    $end = [Math]::Min($total, $start + $MaxOutputLines - 1)
}

Write-Host ""
Write-Host "=== SELECTED SYMBOL WINDOW ==="
Write-Host "Selected line: $($selected.Line)"
Write-Host "Selected kind: $($selected.Kind)"
Write-Host "Detected block: $blockStart-$blockEnd"
Write-Host "Output lines: $start-$end"
Write-Host "Output line count: $($end - $start + 1)"
Write-Host ""
Write-Host "=== SOURCE ==="
for ($i = $start; $i -le $end; $i++) {
    $prefix = if ($i -eq $selected.Line) { ">" } else { " " }
    "{0} {1,5}: {2}" -f $prefix, $i, $lines[$i - 1]
}

Write-Host ""
Write-Host "=== GUIDANCE ==="
Write-Host "Use this symbol window first."
Write-Host "If related imports/types/state are missing, read one nearby window with read-window.ps1 rather than dumping the whole file."
Write-Host "If the selected match is a reference, rerun with a more exact definition symbol."
