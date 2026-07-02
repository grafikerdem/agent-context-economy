param(
    [string]$Filter,
    [switch]$AllowFull,
    [int]$MaxLines = 180,
    [string]$TestCommand = "php artisan test"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Continue"

if (-not $Filter -and -not $AllowFull) {
    Write-Host "ERROR: Refusing to run full test suite without -AllowFull." -ForegroundColor Red
    Write-Host "Use: .\scripts\ai\test.ps1 -Filter <SpecificTest>"
    exit 1
}

$cmd = $TestCommand
if ($Filter) {
    $cmd = "$TestCommand --filter=$Filter"
}

$runCompact = Join-Path $PSScriptRoot "run-compact.ps1"
if (Test-Path -LiteralPath $runCompact) {
    & $runCompact -Command $cmd -MaxLines $MaxLines
    exit $LASTEXITCODE
}

Write-Host "WARNING: run-compact.ps1 not found; running raw command." -ForegroundColor Yellow
Invoke-Expression $cmd
exit $LASTEXITCODE
