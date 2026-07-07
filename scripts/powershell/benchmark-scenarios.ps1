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

# Clean up
Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
