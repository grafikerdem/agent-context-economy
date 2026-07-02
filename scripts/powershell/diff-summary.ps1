param([int]$MaxLines = 120)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "=== GIT STATUS SHORT ==="
git status --short 2>&1 | Select-Object -First $MaxLines

Write-Host ""
Write-Host "=== DIFF STAT ==="
git diff --stat 2>&1 | Select-Object -First $MaxLines

Write-Host ""
Write-Host "=== CHANGED FILES ==="
git diff --name-only 2>&1 | Select-Object -First $MaxLines
