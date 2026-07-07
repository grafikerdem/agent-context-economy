param()

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$tempDir = Join-Path $scriptDir "benchmark-temp"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

# ---------------------------------------------------------------------------
# Setup Fixture Files
# ---------------------------------------------------------------------------

# 1. Large PHP Class (530 lines)
$phpClassPath = Join-Path $tempDir "LargePHPClass.php"
$phpLines = @()
$phpLines += "<?php"
$phpLines += "namespace App\Services;"
$phpLines += "class LargePHPClass extends BaseService implements Processable {"
$phpLines += "    private `$db;"
$phpLines += "    protected `$logger;"
for ($i = 1; $i -le 20; $i++) {
    $phpLines += "    public function method$i(`$arg) {"
    $phpLines += "        // Method $i filler logic"
    for ($j = 1; $j -le 20; $j++) {
        $phpLines += "        `$x = `$arg * $j;"
        $phpLines += "        `$this->logger->debug('processing step ' . `$x);"
    }
    $phpLines += "        return `$x;"
    $phpLines += "    }"
}
$phpLines += "}"
$phpLines | Set-Content -Encoding UTF8 -LiteralPath $phpClassPath

# 2. React Component (410 lines)
$reactComponentPath = Join-Path $tempDir "MyComponent.tsx"
$reactLines = @()
$reactLines += "import React, { useState, useEffect } from 'react';"
$reactLines += "export const MyComponent: React.FC = () => {"
$reactLines += "    const [state, setState] = useState(null);"
for ($i = 1; $i -le 15; $i++) {
    $reactLines += "    const helperMethod$i = () => {"
    for ($j = 1; $j -le 20; $j++) {
        $reactLines += "        console.log('helper $i line $j');"
    }
    $reactLines += "    };"
}
$reactLines += "    return (<div>Hello World</div>);"
$reactLines += "};"
$reactLines | Set-Content -Encoding UTF8 -LiteralPath $reactComponentPath

# 3. Symbol Inspection File (220 lines)
$symbolFilePath = Join-Path $tempDir "SymbolInspection.php"
$symbolLines = @()
$symbolLines += "<?php"
$symbolLines += "class SymbolInspection {"
for ($i = 1; $i -le 8; $i++) {
    $symbolLines += "    public function otherFunc$i() {"
    for ($j = 1; $j -le 20; $j++) {
        $symbolLines += "        `$val = $i * $j;"
    }
    $symbolLines += "    }"
}
$symbolLines += "    public function calculateMargin(`$cost, `$price) {"
$symbolLines += "        `$profit = `$price - `$cost;"
$symbolLines += "        `$margin = (`$profit / `$price) * 100;"
$symbolLines += "        return `$margin;"
$symbolLines += "    }"
$symbolLines += "}"
$symbolLines | Set-Content -Encoding UTF8 -LiteralPath $symbolFilePath

# ---------------------------------------------------------------------------
# Capture & Execution Helpers
# ---------------------------------------------------------------------------

function Capture-Command {
    param([scriptblock]$Script)
    $tmp = New-TemporaryFile
    try {
        & $Script *>&1 | Out-File -FilePath $tmp.FullName -Encoding utf8
        $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $tmp.FullName -ErrorAction SilentlyContinue
        if ($null -eq $text) { return "" } else { return $text }
    }
    finally {
        Remove-Item -LiteralPath $tmp.FullName -Force -ErrorAction SilentlyContinue
    }
}

function Get-LineCount {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return 0 }
    return @($Text -split "`r?`n").Count
}

function Estimate-Tokens {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return 0 }
    # Standard approximation: 1 token = ~4 characters
    return [int]([Math]::Round($Text.Length / 4))
}

# ---------------------------------------------------------------------------
# Run Benchmark
# ---------------------------------------------------------------------------

Write-Host "Running Benchmark Scenarios..." -ForegroundColor Cyan

$readSymbolPath = Join-Path $scriptDir "read-symbol.ps1"
$readTextPath = Join-Path $scriptDir "read-text.ps1"

# Scenario 1: Symbol Inspection (calculateMargin)
# Old: Full read of the 220-line file
$oldSymbolOutput = Get-Content -Raw -Encoding UTF8 -LiteralPath $symbolFilePath
$newSymbolOutput = Capture-Command {
    & $readSymbolPath -Path $symbolFilePath -Symbol "calculateMargin" -Signature -Budget Small
}

# Scenario 2: React Component (MyComponent.tsx)
# Old: Full read of the 410-line file
$oldReactOutput = Get-Content -Raw -Encoding UTF8 -LiteralPath $reactComponentPath
$newReactOutput = Capture-Command {
    & $readTextPath -Path $reactComponentPath -Summary -Budget Small
}

# Scenario 3: Large PHP Class (LargePHPClass.php)
# Old: Full read of the 530-line file
$oldPHPOutput = Get-Content -Raw -Encoding UTF8 -LiteralPath $phpClassPath
$newPHPOutput = Capture-Command {
    & $readTextPath -Path $phpClassPath -Summary -Budget Small
}

# ---------------------------------------------------------------------------
# Generate Metrics
# ---------------------------------------------------------------------------

$scenarios = @(
    @{
        Name = "Symbol Inspection"
        OldLines = Get-LineCount $oldSymbolOutput
        NewLines = Get-LineCount $newSymbolOutput
        OldTokens = Estimate-Tokens $oldSymbolOutput
        NewTokens = Estimate-Tokens $newSymbolOutput
    },
    @{
        Name = "React Component"
        OldLines = Get-LineCount $oldReactOutput
        NewLines = Get-LineCount $newReactOutput
        OldTokens = Estimate-Tokens $oldReactOutput
        NewTokens = Estimate-Tokens $newReactOutput
    },
    @{
        Name = "Large PHP Class"
        OldLines = Get-LineCount $oldPHPOutput
        NewLines = Get-LineCount $newPHPOutput
        OldTokens = Estimate-Tokens $oldPHPOutput
        NewTokens = Estimate-Tokens $newPHPOutput
    }
)

# ---------------------------------------------------------------------------
# Output Results Table
# ---------------------------------------------------------------------------

Write-Host "`n=== BENCHMARK RESULTS ===" -ForegroundColor Green

$resultsTable = @()
foreach ($s in $scenarios) {
    $reductionLines = [Math]::Round((1 - ($s.NewLines / $s.OldLines)) * 100, 1)
    $reductionTokens = [Math]::Round((1 - ($s.NewTokens / $s.OldTokens)) * 100, 1)
    
    $resultsTable += [PSCustomObject]@{
        "Scenario"            = $s.Name
        "Old (Lines)"         = $s.OldLines
        "New (Lines)"         = $s.NewLines
        "Line Reduction"      = "$reductionLines%"
        "Old (Est. Tokens)"   = $s.OldTokens
        "New (Est. Tokens)"   = $s.NewTokens
        "Token Reduction"     = "$reductionTokens%"
    }
}

$resultsTable | Format-Table -AutoSize

# ---------------------------------------------------------------------------
# SVG Generation
# ---------------------------------------------------------------------------
$repoRoot = Resolve-Path (Join-Path $scriptDir "../..")
$outDir = Join-Path $repoRoot "benchmark-results"
$svgPath = Join-Path $outDir "scenarios.svg"

$svgColors = @("#3fb950", "#58a6ff", "#d2a8ff")
$chartRows = @()
$y = 146

for ($idx = 0; $idx -lt $scenarios.Count; $idx++) {
    $s = $scenarios[$idx]
    $reductionTokens = [Math]::Round((1 - ($s.NewTokens / $s.OldTokens)) * 100, 1)
    
    $chartRows += [pscustomobject]@{
        Label = $s.Name
        Detail = "$($s.OldTokens) -> $($s.NewTokens) tokens (Lines: $($s.OldLines) -> $($s.NewLines))"
        Reduction = $reductionTokens
        Color = $svgColors[$idx]
        Y = $y
    }
    $y += 72
}

function Escape-Xml {
    param([AllowEmptyString()][string]$Text)
    return [System.Security.SecurityElement]::Escape($Text)
}

$svg = New-Object System.Collections.Generic.List[string]
$svg.Add('<svg xmlns="http://www.w3.org/2000/svg" width="620" height="384" viewBox="0 0 620 384" role="img" aria-labelledby="title description">')
$svg.Add('  <title id="title">ACE Scenario Token Reduction Benchmark</title>')
$svg.Add('  <desc id="description">Measured token reductions for common targeted reading scenarios.</desc>')
$svg.Add('  <rect width="620" height="384" rx="16" fill="#0d1117"/>')
$svg.Add('  <rect x="1" y="1" width="618" height="382" rx="16" fill="#161b22" stroke="#30363d"/>')
$svg.Add('  <g font-family="Segoe UI, Arial, sans-serif">')
$svg.Add('    <text x="32" y="40" fill="#f0f6fc" font-size="18" font-weight="700">ACE Target Scenarios</text>')
$svg.Add('    <text x="32" y="62" fill="#8b949e" font-size="13">Token Economy Savings by Scenario</text>')
$svg.Add("    <text x=`"32`" y=`"80`" fill=`"#8b949e`" font-size=`"11`">Generated $([DateTime]::UtcNow.ToString('yyyy-MM-dd')) UTC - higher is better</text>")
$svg.Add('    <line x1="32" y1="96" x2="588" y2="96" stroke="#30363d"/>')

foreach ($row in $chartRows) {
    $barWidth = [Math]::Round(338 * ([Math]::Max(0, [Math]::Min(100, $row.Reduction)) / 100), 0)
    $labelY = $row.Y - 8
    $detailY = $row.Y + 25
    $percentY = $row.Y + 16
    $svg.Add("    <text x=`"32`" y=`"$labelY`" fill=`"#c9d1d9`" font-size=`"13`" font-weight=`"600`">$(Escape-Xml $row.Label)</text>")
    $svg.Add("    <text x=`"32`" y=`"$detailY`" fill=`"#8b949e`" font-size=`"11`">$(Escape-Xml $row.Detail)</text>")
    $svg.Add("    <rect x=`"200`" y=`"$($row.Y)`" width=`"338`" height=`"22`" rx=`"6`" fill=`"#21262d`"/>")
    $svg.Add("    <rect x=`"200`" y=`"$($row.Y)`" width=`"$barWidth`" height=`"22`" rx=`"6`" fill=`"$($row.Color)`"/>")
    $svg.Add("    <text x=`"548`" y=`"$percentY`" fill=`"$($row.Color)`" font-size=`"14`" font-weight=`"700`">$($row.Reduction)%</text>")
}

$svg.Add('    <line x1="32" y1="332" x2="588" y2="332" stroke="#30363d"/>')
$svg.Add('    <text x="32" y="354" fill="#8b949e" font-size="10">Benchmark scenarios compare progressive reading to raw file reads.</text>')
$svg.Add('    <text x="32" y="370" fill="#8b949e" font-size="10">Estimates assume 1 token ~= 4 characters.</text>')
$svg.Add('  </g>')
$svg.Add('</svg>')
$svg | Set-Content -Encoding UTF8 -LiteralPath $svgPath

Write-Host "Scenario SVG written: $svgPath" -ForegroundColor Green

# Clean up
Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
