param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [int]$Line,

    [int]$Context = 30
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

function Fail($Message) { Write-Host "ERROR: $Message" -ForegroundColor Red; exit 1 }
if (-not (Test-Path -LiteralPath $Path)) { Fail "File not found: $Path" }
if ($Line -lt 1) { Fail "Line must be >= 1." }
if ($Context -lt 1) { Fail "Context must be >= 1." }

$lines = @(Get-Content -LiteralPath $Path -Encoding UTF8)
$total = $lines.Count
if ($Line -gt $total) { Fail "Requested line $Line is beyond file length $total." }

$start = [Math]::Max(1, $Line - $Context)
$end = [Math]::Min($total, $Line + $Context)

Write-Host ""
Write-Host "=== SOURCE WINDOW ==="
Write-Host "File: $Path"
Write-Host "Lines: $start-$end"
Write-Host "Target line: $Line"
Write-Host "Total lines: $total"
Write-Host "Window lines: $($end - $start + 1)"

Write-Host ""
Write-Host "=== NEARBY ANCHORS ==="
$anchorPatterns = @(
    'class\s+[A-Za-z_][A-Za-z0-9_]*',
    'interface\s+[A-Za-z_][A-Za-z0-9_]*',
    'trait\s+[A-Za-z_][A-Za-z0-9_]*',
    'enum\s+[A-Za-z_][A-Za-z0-9_]*',
    'function\s+[A-Za-z_][A-Za-z0-9_]*',
    '(public|private|protected)\s+function\s+[A-Za-z_][A-Za-z0-9_]*',
    'const\s+[A-Za-z_][A-Za-z0-9_]*\s*=',
    'const\s+[A-Za-z_][A-Za-z0-9_]*\s*:',
    'use(Form|Effect|Memo|Callback|State)\s*\(',
    'Route::',
    'Schema::',
    'it\(',
    'test\('
)

$anchorStart = [Math]::Max(1, $Line - [Math]::Max($Context, 80))
$anchorEnd = [Math]::Min($total, $Line + [Math]::Max($Context, 80))
$anchors = @()
for ($i = $anchorStart; $i -le $anchorEnd; $i++) {
    $text = $lines[$i - 1]
    foreach ($p in $anchorPatterns) {
        if ($text -match $p) {
            $anchors += @{ Line = $i; Text = $text.Trim() }
            break
        }
    }
}

if ($anchors.Count -eq 0) {
    Write-Host "No nearby anchors detected."
} else {
    foreach ($a in ($anchors | Select-Object -First 20)) { "{0,5}: {1}" -f $a.Line, $a.Text }
}

Write-Host ""
Write-Host "=== CODE ==="
for ($i = $start; $i -le $end; $i++) {
    $prefix = if ($i -eq $Line) { ">" } else { " " }
    "{0} {1,5}: {2}" -f $prefix, $i, $lines[$i - 1]
}

Write-Host ""
Write-Host "=== GUIDANCE ==="
Write-Host "Read only this window first."
Write-Host "If context is insufficient, state what is missing and read the next smallest related symbol/window."
Write-Host "Do not dump the whole file unless explicitly approved."
Write-Host "If this is the third window in the same known large file, stop and use find-in-file/read-symbol or summarize what is missing."
