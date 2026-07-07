param()

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Continue"

Write-Host "Preparing AI helper scripts..."

if (Get-Command Unblock-File -ErrorAction SilentlyContinue) {
    Get-ChildItem $PSScriptRoot -Filter *.ps1 -ErrorAction SilentlyContinue |
        ForEach-Object {
            try {
                Unblock-File -LiteralPath $_.FullName -ErrorAction SilentlyContinue
                Write-Host "[OK] $($_.Name)"
            } catch {
                Write-Host "[WARN] Could not unblock $($_.Name): $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
} else {
    Write-Host "No file unblocking required on this platform."
}

Write-Host "Done."
