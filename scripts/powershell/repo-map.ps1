param(
    [string]$Root = ".",
    [string]$OutputPath = ".agent-context/repo-map.md",
    [int]$MaxEntries = 20
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

function Get-RelativePath([string]$BasePath, [string]$FullPath) {
    $baseUri = New-Object System.Uri(($BasePath.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar))
    $pathUri = New-Object System.Uri($FullPath)
    return [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($pathUri).ToString()).Replace('/', [IO.Path]::DirectorySeparatorChar)
}

function Test-Excluded([string]$RelativePath) {
    $parts = $RelativePath -split '[\\/]'
    $excluded = @('.git', '.agent-context', 'node_modules', 'vendor', 'dist', 'build', 'coverage', '.next', '.nuxt', 'bin', 'obj')
    foreach ($part in $parts) {
        if ($excluded -contains $part) { return $true }
    }
    return $false
}

function Get-GitValue([string]$RootPath, [string[]]$Arguments) {
    try {
        $output = & git -C $RootPath @Arguments 2>$null
        if ($LASTEXITCODE -eq 0 -and $null -ne $output) {
            return (($output | Out-String).Trim())
        }
    } catch {
        return $null
    }
    return $null
}

function Get-GitMetadata([string]$RootPath) {
    $insideWorkTree = Get-GitValue -RootPath $RootPath -Arguments @('rev-parse', '--is-inside-work-tree')
    if ($insideWorkTree -ne 'true') {
        return [PSCustomObject]@{
            Commit = 'unavailable'
            Tree = 'unavailable'
            DirtyState = 'unknown (not a git work tree)'
        }
    }

    $commit = Get-GitValue -RootPath $RootPath -Arguments @('rev-parse', 'HEAD')
    $tree = Get-GitValue -RootPath $RootPath -Arguments @('rev-parse', 'HEAD^{tree}')
    $status = Get-GitValue -RootPath $RootPath -Arguments @('status', '--porcelain')
    $dirtyState = 'clean'
    if (-not [string]::IsNullOrWhiteSpace($status)) { $dirtyState = 'dirty' }

    if ([string]::IsNullOrWhiteSpace($commit)) { $commit = 'unavailable' }
    if ([string]::IsNullOrWhiteSpace($tree)) { $tree = 'unavailable' }

    return [PSCustomObject]@{
        Commit = $commit
        Tree = $tree
        DirtyState = $dirtyState
    }
}

if (-not (Test-Path -LiteralPath $Root -PathType Container)) { Fail "Repository root not found: $Root" }

$rootPath = (Resolve-Path -LiteralPath $Root).Path
$agentContextPath = [IO.Path]::GetFullPath((Join-Path $rootPath ".agent-context"))
$resolvedOutputPath = if ([IO.Path]::IsPathRooted($OutputPath)) {
    [IO.Path]::GetFullPath($OutputPath)
} else {
    [IO.Path]::GetFullPath((Join-Path $rootPath $OutputPath))
}

$allowedPrefix = $agentContextPath.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $resolvedOutputPath.StartsWith($allowedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    Fail "OutputPath must be inside $agentContextPath"
}

$allFiles = @(Get-ChildItem -LiteralPath $rootPath -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
    $relative = Get-RelativePath -BasePath $rootPath -FullPath $_.FullName
    -not (Test-Excluded $relative)
})

$topDirectories = @(Get-ChildItem -LiteralPath $rootPath -Directory -ErrorAction SilentlyContinue | Where-Object {
    -not (Test-Excluded $_.Name)
} | Sort-Object Name)

$commonDirectoryNames = @('src', 'app', 'lib', 'packages', 'modules', 'resources', 'routes', 'tests', 'test', 'scripts', 'docs', 'config')
$sourceDirectories = @(Get-ChildItem -LiteralPath $rootPath -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object {
    $relative = Get-RelativePath -BasePath $rootPath -FullPath $_.FullName
    (-not (Test-Excluded $relative)) -and ($commonDirectoryNames -contains $_.Name.ToLowerInvariant())
} | Sort-Object FullName | Select-Object -First $MaxEntries)

$entryPointNames = @(
    'package.json', 'composer.json', 'Cargo.toml', 'go.mod', '*.sln', '*.csproj',
    'main.*', 'index.*', 'app.*', 'Program.cs', 'artisan', 'manage.py',
    'Dockerfile', 'Makefile', 'README.md', 'AGENTS.md'
)
$entryPoints = @($allFiles | Where-Object {
    $name = $_.Name
    foreach ($pattern in $entryPointNames) {
        if ($name -like $pattern) { return $true }
    }
    return $false
} | Sort-Object FullName | Select-Object -First $MaxEntries)

$gitMetadata = Get-GitMetadata -RootPath $rootPath

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# Repository Map')
$lines.Add('')
$lines.Add("Generated: $([DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')) UTC")
$lines.Add("Root: ``$rootPath``")
$lines.Add("Files counted: $($allFiles.Count)")
$lines.Add("Git commit: ``$($gitMetadata.Commit)``")
$lines.Add("Git tree: ``$($gitMetadata.Tree)``")
$lines.Add("Git dirty state: $($gitMetadata.DirtyState)")
$lines.Add('Valid until: regenerate this map after files are added, removed, moved, or when the git tree changes.')
$lines.Add('Authority: use this map for orientation only; read or grep target files before editing.')
$lines.Add('')
$lines.Add('## Top-level directories')
$lines.Add('')
if ($topDirectories.Count -eq 0) {
    $lines.Add('- None')
} else {
    foreach ($directory in ($topDirectories | Select-Object -First $MaxEntries)) {
        $prefix = $directory.FullName.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        $count = @($allFiles | Where-Object { $_.FullName.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) }).Count
        $lines.Add("- ``$($directory.Name)/`` - $count files")
    }
}
$lines.Add('')
$lines.Add('## Common source directories')
$lines.Add('')
if ($sourceDirectories.Count -eq 0) {
    $lines.Add('- None detected')
} else {
    foreach ($directory in $sourceDirectories) {
        $relative = (Get-RelativePath -BasePath $rootPath -FullPath $directory.FullName).Replace('\', '/')
        $prefix = $directory.FullName.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        $count = @($allFiles | Where-Object { $_.FullName.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) }).Count
        $lines.Add("- ``$relative/`` - $count files")
    }
}
$lines.Add('')
$lines.Add('## Likely entry points')
$lines.Add('')
if ($entryPoints.Count -eq 0) {
    $lines.Add('- None detected')
} else {
    foreach ($file in $entryPoints) {
        $relative = (Get-RelativePath -BasePath $rootPath -FullPath $file.FullName).Replace('\', '/')
        $lines.Add("- ``$relative``")
    }
}
$lines.Add('')
$lines.Add('> Generated from file names and directory structure only. Read repository instructions before making changes.')

$outputDirectory = Split-Path -Parent $resolvedOutputPath
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}
$lines | Out-File -LiteralPath $resolvedOutputPath -Encoding utf8

Write-Host "Repository map written: $resolvedOutputPath"
Write-Host "Files counted: $($allFiles.Count)"
Write-Host "Top-level directories: $($topDirectories.Count)"
Write-Host "Likely entry points: $($entryPoints.Count)"
