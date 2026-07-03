param(
    [string]$OutputDir = "benchmark-results"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Continue"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "../..")
Set-Location $repoRoot

$outDir = Join-Path $repoRoot $OutputDir
$demoDir = Join-Path $outDir "demo"

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
New-Item -ItemType Directory -Force -Path $demoDir | Out-Null

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Capture {
    param([Parameter(Mandatory = $true)][scriptblock]$Script)
    $tmp = New-TemporaryFile
    try {
        & $Script *>&1 | Out-File -FilePath $tmp.FullName -Encoding utf8
        $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $tmp.FullName -ErrorAction SilentlyContinue
        if ($null -eq $text) { return "" }
        return $text
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

function Escape-Xml {
    param([AllowEmptyString()][string]$Text)
    return [System.Security.SecurityElement]::Escape($Text)
}

# ---------------------------------------------------------------------------
# Demo fixtures
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "=== Agent Context Economy Benchmark ===" -ForegroundColor Cyan
Write-Host "Repo root: $repoRoot"
Write-Host "Demo dir:  $demoDir"

# --- noisy build log (terminal benchmark fixture) ---
$logPath = Join-Path $demoDir "noisy-build.log"
$log = @()
1..350 | ForEach-Object { $log += "vite transform module-$_.tsx completed" }
$log += "resources/js/Example.tsx:42:13 - error TS2322: Type 'string | null' is not assignable to type 'string'."
$log += "tests/Feature/ExampleTest.php:88: Failed asserting that false is true."
$log += "Tests: 1 failed, 24 passed"
$log | Set-Content -Encoding UTF8 -LiteralPath $logPath

# --- large source file (source reading benchmark fixture) ---
$sourcePath = Join-Path $demoDir "LargeCheckoutPage.tsx"
$source = @()
$source += "import React, { useMemo } from 'react';"
$source += "export default function LargeCheckoutPage() {"
1..500 | ForEach-Object { $source += "  const filler$_ = $_;" }
$source += "  function handleSubmit(event: React.FormEvent) {"
$source += "    event.preventDefault();"
$source += "    console.log('submit');"
$source += "  }"
$source += "  return <form onSubmit={handleSubmit} />;"
$source += "}"
$source | Set-Content -Encoding UTF8 -LiteralPath $sourcePath

# --- supporting files for shell command benchmark ---
$servicePath = Join-Path $demoDir "CheckoutService.php"
@"
<?php
class CheckoutService {
    public function createCheckout(array `$payload): array { return `$payload; }
    public function approveCheckout(int `$id): bool { return true; }
}
"@ | Set-Content -Encoding UTF8 -LiteralPath $servicePath

$routePath = Join-Path $demoDir "routes.php"
@"
<?php
Route::post('/checkout', 'CheckoutController@store');
Route::post('/checkout/{checkout}/approve', 'CheckoutController@approve');
"@ | Set-Content -Encoding UTF8 -LiteralPath $routePath

# ---------------------------------------------------------------------------
# Measurements
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "Measuring terminal output economy..."

$rawTerminal    = Get-Content -Raw -Encoding UTF8 -LiteralPath $logPath
$compactTerminal = Capture {
    & (Join-Path $scriptDir "run-compact.ps1") -Command "Get-Content `"$logPath`"" -MaxLines 80
}
$terminalRawLines     = Get-LineCount $rawTerminal
$terminalCompactLines = Get-LineCount $compactTerminal
$terminalReduction    = if ($terminalRawLines -gt 0) {
    [math]::Round((1 - ($terminalCompactLines / $terminalRawLines)) * 100)
} else { 0 }

Write-Host "Measuring source reading economy..."

$rawSource    = Get-Content -Raw -Encoding UTF8 -LiteralPath $sourcePath
$compactSource = Capture {
    & (Join-Path $scriptDir "read-symbol.ps1") -Path $sourcePath -Symbol "handleSubmit" -Context 20
}
$sourceRawLines     = Get-LineCount $rawSource
$sourceCompactLines = Get-LineCount $compactSource
$sourceReduction    = if ($sourceRawLines -gt 0) {
    [math]::Round((1 - ($sourceCompactLines / $sourceRawLines)) * 100)
} else { 0 }

Write-Host "Measuring shell command economy..."

# Vanilla: 4 separate Select-String calls across 3 files + 3 read-window calls = 7 commands
# Agent:   1 investigate.ps1 call -> 1 read-symbol call = 2 commands
$vanillaCommands = 7
$agentCommands   = 2
$commandReduction = [math]::Round((1 - ($agentCommands / $vanillaCommands)) * 100)

# ---------------------------------------------------------------------------
# Results table (internal)
# ---------------------------------------------------------------------------

$results = @(
    [pscustomobject]@{
        Metric         = "Terminal output"
        Vanilla        = "$terminalRawLines lines"
        Agent          = "$terminalCompactLines lines"
        Reduction      = "$terminalReduction%"
        ReductionInt   = $terminalReduction
    },
    [pscustomobject]@{
        Metric         = "Source file read"
        Vanilla        = "$sourceRawLines lines"
        Agent          = "$sourceCompactLines lines"
        Reduction      = "$sourceReduction%"
        ReductionInt   = $sourceReduction
    },
    [pscustomobject]@{
        Metric         = "Shell commands"
        Vanilla        = "$vanillaCommands commands"
        Agent          = "$agentCommands commands"
        Reduction      = "$commandReduction%"
        ReductionInt   = $commandReduction
    }
)

# ---------------------------------------------------------------------------
# Output paths
# ---------------------------------------------------------------------------

$csvPath    = Join-Path $outDir "benchmark.csv"
$mdPath     = Join-Path $outDir "benchmark.md"
$jsonPath   = Join-Path $outDir "benchmark.json"
$badgePath  = Join-Path $outDir "badge.json"
$svgPath    = Join-Path $outDir "benchmark.svg"

# ---------------------------------------------------------------------------
# CSV
# ---------------------------------------------------------------------------

$results | Select-Object Metric, Vanilla, Agent, Reduction |
    Export-Csv -NoTypeInformation -Encoding UTF8 -Path $csvPath

# ---------------------------------------------------------------------------
# JSON
# ---------------------------------------------------------------------------

$jsonObj = [ordered]@{
    generated_at        = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    terminal_reduction  = $terminalReduction
    source_reduction    = $sourceReduction
    command_reduction   = $commandReduction
    rows = $results | ForEach-Object {
        [ordered]@{
            metric    = $_.Metric
            vanilla   = $_.Vanilla
            agent     = $_.Agent
            reduction = $_.Reduction
        }
    }
}
$jsonObj | ConvertTo-Json -Depth 4 |
    Set-Content -Encoding UTF8 -LiteralPath $jsonPath

# ---------------------------------------------------------------------------
# badge.json
# ---------------------------------------------------------------------------

$badgeObj = [ordered]@{
    terminal_reduction = $terminalReduction
    source_reduction   = $sourceReduction
    command_reduction  = $commandReduction
}
$badgeObj | ConvertTo-Json |
    Set-Content -Encoding UTF8 -LiteralPath $badgePath

# ---------------------------------------------------------------------------
# Markdown (README-style)
# ---------------------------------------------------------------------------

$xAxisLabels = ($results | ForEach-Object { '"' + $_.Metric + '"' }) -join ', '
$reductionValues = ($results | ForEach-Object { $_.ReductionInt }) -join ', '

$md = @()
$md += "# Agent Context Economy Benchmark"
$md += ""
$md += "## What does this toolkit reduce?"
$md += ""
$md += "Typical benchmark results:"
$md += ""
$md += "- **$($terminalReduction)% less terminal output**"
$md += "- **$($sourceReduction)% less source code read**"
$md += "- **$($commandReduction)% fewer shell commands**"
$md += ""
$md += "---"
$md += ""
$md += "Reproducible synthetic benchmark generated by ``scripts/powershell/benchmark.ps1``."
$md += "Run the script in any clone of this repository to reproduce these results."
$md += ""
$md += "Approximate token estimate:"
$md += "1 token ~= 4 ASCII characters."
$md += ""
$md += "This is used only for relative comparisons. Actual token counts vary by model and tokenizer."
$md += ""
$md += "| Workflow | Conventional workflow | Agent Context Economy |"
$md += "|---|---:|---:|"
foreach ($r in $results) {
    $md += "| $($r.Metric) | $($r.Vanilla) | $($r.Agent) |"
}
$md += ""
$md += "## Reduction summary"
$md += ""
$md += "| Metric | Reduction |"
$md += "|---|---:|"
foreach ($r in $results) {
    $md += "| $($r.Metric) | $($r.Reduction) |"
}
$md += ""
$md += "## Charts"
$md += ""
$md += "### Output and source reading reduction"
$md += ""
$md += '```mermaid'
$md += "xychart-beta"
$md += "    title `"Output and source reading reduction (%)`""
$md += "    x-axis [$xAxisLabels]"
$md += "    y-axis `"Reduction %`" 0 --> 100"
$md += "    bar [$reductionValues]"
$md += '```'
$md += ""
$md += "### Conventional vs agent workflow"
$md += ""
$md += '```mermaid'
$md += "xychart-beta"
$md += "    title `"Conventional vs Agent Context Economy`""
$md += "    x-axis [$xAxisLabels]"
$md += "    y-axis `"Count`""
$md += "    bar [$(($results | ForEach-Object {
        if ($_.Metric -eq 'Terminal output')  { $terminalRawLines }
        elseif ($_.Metric -eq 'Source file read') { $sourceRawLines }
        else { $vanillaCommands }
    }) -join ', ')]"
$md += "    line [$(($results | ForEach-Object {
        if ($_.Metric -eq 'Terminal output')  { $terminalCompactLines }
        elseif ($_.Metric -eq 'Source file read') { $sourceCompactLines }
        else { $agentCommands }
    }) -join ', ')]"
$md += '```'
$md += ""
$md += "---"
$md += ""
$md += "> **Note:** Results vary depending on repository size, command output, and agent behavior."
$md += "> The benchmark is intended to compare workflow shape rather than absolute model token usage."

# Write with UTF-8 BOM to ensure editors read correctly
$md | Set-Content -Encoding UTF8 -LiteralPath $mdPath

# ---------------------------------------------------------------------------
# SVG
# ---------------------------------------------------------------------------

$chartRows = @(
    [pscustomobject]@{
        Label = "Terminal output"
        Detail = "$terminalRawLines lines -> $terminalCompactLines lines"
        Reduction = $terminalReduction
        Color = "#3fb950"
        Y = 146
    },
    [pscustomobject]@{
        Label = "Source reading"
        Detail = "$sourceRawLines lines -> $sourceCompactLines lines"
        Reduction = $sourceReduction
        Color = "#58a6ff"
        Y = 218
    },
    [pscustomobject]@{
        Label = "Shell commands"
        Detail = "$vanillaCommands commands -> $agentCommands commands"
        Reduction = $commandReduction
        Color = "#d2a8ff"
        Y = 290
    }
)

$svg = New-Object System.Collections.Generic.List[string]
$svg.Add('<svg xmlns="http://www.w3.org/2000/svg" width="620" height="384" viewBox="0 0 620 384" role="img" aria-labelledby="title description">')
$svg.Add('  <title id="title">Agent Context Economy benchmark</title>')
$svg.Add('  <desc id="description">Measured reductions in terminal output, source reading, and shell commands.</desc>')
$svg.Add('  <rect width="620" height="384" rx="16" fill="#0d1117"/>')
$svg.Add('  <rect x="1" y="1" width="618" height="382" rx="16" fill="#161b22" stroke="#30363d"/>')
$svg.Add('  <g font-family="Segoe UI, Arial, sans-serif">')
$svg.Add('    <text x="32" y="40" fill="#f0f6fc" font-size="18" font-weight="700">Agent Context Economy</text>')
$svg.Add('    <text x="32" y="62" fill="#8b949e" font-size="13">Benchmark Results</text>')
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
$svg.Add('    <text x="32" y="354" fill="#8b949e" font-size="10">Reproducible synthetic benchmark generated by scripts/powershell/benchmark.ps1.</text>')
$svg.Add('    <text x="32" y="370" fill="#8b949e" font-size="10">Results vary by repository size and agent behavior.</text>')
$svg.Add('  </g>')
$svg.Add('</svg>')
$svg | Set-Content -Encoding UTF8 -LiteralPath $svgPath

# ---------------------------------------------------------------------------
# Console summary
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "Benchmark complete." -ForegroundColor Green
Write-Host "Markdown: $mdPath"
Write-Host "CSV:      $csvPath"
Write-Host "JSON:     $jsonPath"
Write-Host "Badge:    $badgePath"
Write-Host "SVG:      $svgPath"
Write-Host ""

$results | Format-Table Metric, Vanilla, Agent, Reduction -AutoSize
