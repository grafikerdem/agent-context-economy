param(
    [int]$MaxPreviewLines = 120
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Continue"
$script:Failed = $false

function Section($Title) { Write-Host ""; Write-Host "=== $Title ===" -ForegroundColor Cyan }
function Pass($Message) { Write-Host "[PASS] $Message" -ForegroundColor Green }
function Warn($Message) { Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Fail($Message) { Write-Host "[FAIL] $Message" -ForegroundColor Red; $script:Failed = $true }

function Run-Check {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Script,
        [string]$DisplayCommand,
        [string[]]$Expected = @(),
        [int]$MaxAllowedLines = 180,
        [switch]$AllowNonZeroExit
    )

    Section $Name
    if ($DisplayCommand) { Write-Host "Command: $DisplayCommand" }
    $tempFile = New-TemporaryFile
    try {
        $global:LASTEXITCODE = 0
        & $Script *>&1 | Out-File -FilePath $tempFile.FullName -Encoding utf8
        $exitCode = $LASTEXITCODE
        $lines = @(Get-Content -LiteralPath $tempFile.FullName -ErrorAction SilentlyContinue)
        $lineCount = $lines.Count
        $joined = ($lines -join "`n")
        $lines | Select-Object -First $MaxPreviewLines
        if ($lineCount -gt $MaxPreviewLines) { Write-Host "... output truncated in smoke test ($lineCount lines total)" -ForegroundColor Yellow }
        if ($exitCode -ne 0 -and -not $AllowNonZeroExit) { Fail "$Name exited with code $exitCode" } else { Pass "$Name command executed" }
        foreach ($needle in $Expected) {
            if ($joined -match [regex]::Escape($needle)) { Pass "$Name contains expected marker: $needle" } else { Fail "$Name missing expected marker: $needle" }
        }
        if ($lineCount -le $MaxAllowedLines) { Pass "$Name output line count is acceptable: $lineCount" } else { Warn "$Name output is large: $lineCount lines. Consider tightening compact behavior." }
    }
    finally { Remove-Item -LiteralPath $tempFile.FullName -Force -ErrorAction SilentlyContinue }
}

Section "AI Script Smoke Test"
Write-Host "Repository: $(Get-Location)"
Write-Host "Max preview lines per command: $MaxPreviewLines"

Get-ChildItem $PSScriptRoot -Filter *.ps1 -ErrorAction SilentlyContinue | Unblock-File

$tempDir = Join-Path (Get-Location) ".agent-context-economy-smoke"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
$tempFile = Join-Path $tempDir "SampleService.php"
@'
<?php

namespace App\Services;

class SampleService
{
    public function handleSample(): string
    {
        return 'sample';
    }

    public function manager(): string
    {
        return 'manager';
    }
}
'@ | Out-File -LiteralPath $tempFile -Encoding utf8

try {
    Run-Check `
        -Name "search compact summary" `
        -DisplayCommand ".\scripts\ai\search.ps1 -Pattern `"SampleService`" -Path `"$tempDir`"" `
        -Script { & (Join-Path $PSScriptRoot "search.ps1") -Pattern "SampleService" -Path $tempDir } `
        -Expected @("AI SEARCH SUMMARY", "TOP FILES", "RECOMMENDED NEXT STEP") `
        -MaxAllowedLines 90

    Run-Check `
        -Name "investigate batching" `
        -DisplayCommand ".\scripts\ai\investigate.ps1 -Patterns `"SampleService`",`"manager`" -Paths `"$tempDir`"" `
        -Script { & (Join-Path $PSScriptRoot "investigate.ps1") -Patterns "SampleService","manager" -Paths $tempDir } `
        -Expected @("AI INVESTIGATION SUMMARY", "RECOMMENDED NEXT 3 COMMANDS", "AGENT INSTRUCTION") `
        -MaxAllowedLines 140

    Run-Check `
        -Name "find-in-file literal" `
        -DisplayCommand ".\scripts\ai\find-in-file.ps1 -Path `"$tempFile`" -Pattern `"public function manager(`"" `
        -Script { & (Join-Path $PSScriptRoot "find-in-file.ps1") -Path $tempFile -Pattern "public function manager(" } `
        -Expected @("FILE SEARCH", "RECOMMENDED NEXT STEP") `
        -MaxAllowedLines 80

    Run-Check `
        -Name "read-window" `
        -DisplayCommand ".\scripts\ai\read-window.ps1 -Path `"$tempFile`" -Line 8 -Context 5" `
        -Script { & (Join-Path $PSScriptRoot "read-window.ps1") -Path $tempFile -Line 8 -Context 5 } `
        -Expected @("SOURCE WINDOW", "GUIDANCE") `
        -MaxAllowedLines 100

    Run-Check `
        -Name "read-symbol" `
        -DisplayCommand ".\scripts\ai\read-symbol.ps1 -Path `"$tempFile`" -Symbol `"manager`" -Context 5" `
        -Script { & (Join-Path $PSScriptRoot "read-symbol.ps1") -Path $tempFile -Symbol "manager" -Context 5 } `
        -Expected @("SYMBOL NAVIGATOR", "MATCH CANDIDATES", "SELECTED SYMBOL WINDOW") `
        -MaxAllowedLines 120

    Run-Check `
        -Name "read-text UTF-8" `
        -DisplayCommand ".\scripts\ai\read-text.ps1 -Path `"$tempFile`"" `
        -Script { & (Join-Path $PSScriptRoot "read-text.ps1") -Path $tempFile -MaxLines 20 } `
        -Expected @("UTF-8 TEXT READ") `
        -MaxAllowedLines 60

    Run-Check `
        -Name "run-compact simple command" `
        -DisplayCommand ".\scripts\ai\run-compact.ps1 -Command `"Write-Output ok`"" `
        -Script { & (Join-Path $PSScriptRoot "run-compact.ps1") -Command "Write-Output ok" -MaxLines 80 } `
        -Expected @("COMMAND", "RESULT") `
        -MaxAllowedLines 120
}
finally {
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Section "Smoke Test Result"
if ($script:Failed) { Write-Host "AI script smoke test finished with failures." -ForegroundColor Red; exit 1 }
Write-Host "AI script smoke test passed." -ForegroundColor Green
exit 0
