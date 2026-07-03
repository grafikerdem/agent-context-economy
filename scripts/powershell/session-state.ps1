param(
    [Parameter(Position = 0)]
    [ValidateSet('show', 'set-task', 'add-file', 'add-search', 'clear')]
    [string]$Action = 'show',

    [string]$Value,
    [string]$Root = "."
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

function Assert-SafeMetadata([string]$Text, [string]$Label, [int]$MaxLength) {
    if ([string]::IsNullOrWhiteSpace($Text)) { Fail "$Label is required. Pass it with -Value." }
    if ($Text.Length -gt $MaxLength) { Fail "$Label must be $MaxLength characters or fewer." }
    if ($Text -match '[\r\n]') { Fail "$Label must be a single line. Do not store file contents or command output." }
    $secretPattern = '(?i)(password|passwd|secret|api[_-]?key|access[_-]?token|bearer|private[_-]?key)\s*[:=]'
    if ($Text -match $secretPattern -or $Text -match '-----BEGIN [A-Z ]*PRIVATE KEY-----') {
        Fail "$Label looks like secret material. Session state must contain metadata only."
    }
}

function New-State {
    return [ordered]@{
        version = 1
        task = ''
        files = @()
        searches = @()
        updatedAt = $null
    }
}

function Read-State([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return (New-State) }
    try {
        $parsed = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
        return [ordered]@{
            version = 1
            task = [string]$parsed.task
            files = @($parsed.files | Where-Object { $null -ne $_ })
            searches = @($parsed.searches | Where-Object { $null -ne $_ })
            updatedAt = $parsed.updatedAt
        }
    } catch {
        Fail "Could not read session state: $($_.Exception.Message)"
    }
}

function Write-State($State, [string]$Path) {
    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    $State.updatedAt = [DateTime]::UtcNow.ToString('o')
    $State | ConvertTo-Json -Depth 4 | Out-File -LiteralPath $Path -Encoding utf8
}

function Show-State($State, [string]$Path) {
    Write-Host "=== ACE SESSION STATE ==="
    Write-Host "Path: $Path"
    Write-Host "Task: $(if ($State.task) { $State.task } else { '(not set)' })"
    Write-Host "Files: $($State.files.Count)"
    foreach ($file in $State.files) { Write-Host "- $file" }
    Write-Host "Searches: $($State.searches.Count)"
    foreach ($search in $State.searches) { Write-Host "- $search" }
    Write-Host "Updated: $(if ($State.updatedAt) { $State.updatedAt } else { '(not written)' })"
    Write-Host "Metadata only. Never store secrets, file contents, or command output."
}

if (-not (Test-Path -LiteralPath $Root -PathType Container)) { Fail "Repository root not found: $Root" }
$rootPath = (Resolve-Path -LiteralPath $Root).Path
$statePath = Join-Path $rootPath ".agent-context/session-state.json"

if ($Action -eq 'clear') {
    if (Test-Path -LiteralPath $statePath) {
        Remove-Item -LiteralPath $statePath -Force
        Write-Host "Session state cleared: $statePath"
    } else {
        Write-Host "Session state is already clear: $statePath"
    }
    exit 0
}

$state = Read-State $statePath

switch ($Action) {
    'show' {
        Show-State -State $state -Path $statePath
    }
    'set-task' {
        Assert-SafeMetadata -Text $Value -Label 'Task' -MaxLength 500
        $state.task = $Value.Trim()
        Write-State -State $state -Path $statePath
        Write-Host "Session task updated."
    }
    'add-file' {
        Assert-SafeMetadata -Text $Value -Label 'File path' -MaxLength 300
        $candidate = if ([IO.Path]::IsPathRooted($Value)) { [IO.Path]::GetFullPath($Value) } else { [IO.Path]::GetFullPath((Join-Path $rootPath $Value)) }
        $rootPrefix = $rootPath.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        if (-not $candidate.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) { Fail "File path must be inside the repository root." }
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { Fail "File not found: $Value" }
        $relative = $candidate.Substring($rootPrefix.Length).Replace('\', '/')
        $state.files = @($state.files + $relative | Select-Object -Unique | Select-Object -Last 12)
        Write-State -State $state -Path $statePath
        Write-Host "Relevant file recorded: $relative"
    }
    'add-search' {
        Assert-SafeMetadata -Text $Value -Label 'Search' -MaxLength 200
        $state.searches = @($state.searches + $Value.Trim() | Select-Object -Unique | Select-Object -Last 12)
        Write-State -State $state -Path $statePath
        Write-Host "Useful search recorded."
    }
}
