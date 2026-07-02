param(
    [Parameter(Mandatory = $true)]
    [string]$Command,

    [int]$MaxLines = 180
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "=== OUTPUT COMPARISON ==="
Write-Host "Command: $Command"

$rawTemp = New-TemporaryFile
$compactTemp = New-TemporaryFile

try {
    Invoke-Expression $Command 2>&1 | Out-File -FilePath $rawTemp.FullName -Encoding utf8
    $rawExit = $LASTEXITCODE

    $runCompact = Join-Path $PSScriptRoot "run-compact.ps1"
    & $runCompact -Command $Command -MaxLines $MaxLines 2>&1 | Out-File -FilePath $compactTemp.FullName -Encoding utf8
    $compactExit = $LASTEXITCODE

    $rawText = Get-Content -LiteralPath $rawTemp.FullName -Raw -Encoding UTF8
    $compactText = Get-Content -LiteralPath $compactTemp.FullName -Raw -Encoding UTF8

    $rawLines = @($rawText -split "`r?`n")
    $compactLines = @($compactText -split "`r?`n")

    $rawChars = $rawText.Length
    $compactChars = $compactText.Length
    $savings = if ($rawChars -gt 0) { [Math]::Round((1 - ($compactChars / $rawChars)) * 100, 2) } else { 0 }

    Write-Host ""
    Write-Host "Raw exit code: $rawExit"
    Write-Host "Compact exit code: $compactExit"
    Write-Host "Raw lines: $($rawLines.Count)"
    Write-Host "Compact lines: $($compactLines.Count)"
    Write-Host "Raw chars: $rawChars"
    Write-Host "Compact chars: $compactChars"
    Write-Host "Approx char savings: $savings%"

    Write-Host ""
    Write-Host "=== COMPACT PREVIEW ==="
    $compactLines | Select-Object -First 80
}
finally {
    Remove-Item -LiteralPath $rawTemp.FullName -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $compactTemp.FullName -Force -ErrorAction SilentlyContinue
}
