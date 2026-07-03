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

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# Repository Map')
$lines.Add('')
$lines.Add("Generated: $([DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')) UTC")
$lines.Add("Root: ``$rootPath``")
$lines.Add("Files counted: $($allFiles.Count)")
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
