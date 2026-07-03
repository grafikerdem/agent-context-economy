param(
    [Parameter(Mandatory = $true)]
    [string]$Command,

    [int]$MaxLines = 180,

    [int]$Context = 2
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Continue"

function Get-WindowedLines {
    param(
        [object[]]$Lines,
        [int[]]$Indexes,
        [int]$Context = 2
    )

    $selected = New-Object System.Collections.Generic.HashSet[int]

    foreach ($idx in $Indexes) {
        for ($i = [Math]::Max(0, $idx - $Context); $i -le [Math]::Min($Lines.Count - 1, $idx + $Context); $i++) {
            [void]$selected.Add($i)
        }
    }

    $ordered = $selected | Sort-Object
    foreach ($i in $ordered) {
        $Lines[$i]
    }
}

function Get-ProvenanceContext {
    $context = @{ Repo = "unknown"; Git = "unknown@unknown" }
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $repo = & git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and $repo) { $context.Repo = ($repo | Select-Object -First 1) }
        $branch = & git branch --show-current 2>$null
        $head = & git rev-parse --short HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and $head) {
            if (-not $branch) { $branch = "detached" }
            $context.Git = "$branch@$head"
        }
    }
    return $context
}

Write-Host ""
Write-Host "=== COMMAND ==="
Write-Host $Command
Write-Host ""
Write-Host "=== COMPACT OUTPUT ==="

$output = Invoke-Expression $Command 2>&1
$exitCode = $LASTEXITCODE
if ($null -eq $exitCode) { $exitCode = if ($?) { 0 } else { 1 } }

$rawLines = @($output | ForEach-Object { $_.ToString() })

$patterns = @(
    '(?i)\b(error|failed|failure|exception|fatal|warning)\b',
    'TS\d{4}',
    'Type ''',
    'Property ''',
    'Cannot find',
    'not assignable',
    'does not exist',
    'No overload matches',
    'Argument of type',
    'is possibly',
    'implicitly has an',
    'Build failed',
    'RollupError',
    'Transform failed',
    'Could not resolve',
    'error during build',
    '\bFAIL\b',
    '\bFAILED\b',
    '\bERRORS?\b',
    'Tests:',
    'Duration:',
    'Failed asserting',
    'Expected',
    'Actual',
    'ParseError',
    'TypeError',
    'ErrorException',
    'QueryException',
    'ValidationException',
    'AuthorizationException',
    'tests[\\/].*\.(php|ts|tsx|js|jsx):\d+',
    'app[\\/].*\.(php|ts|tsx|js|jsx):\d+',
    'resources[\\/].*\.(php|ts|tsx|js|jsx):\d+',
    '\.php:\d+',
    '\.tsx?:\d+',
    '\.jsx?:\d+'
)

$exclude = @(
    'node_modules',
    'vendor[\\/]',
    'webpack compiled',
    'vite v',
    'Browserslist',
    'DeprecationWarning'
)

$matchIndexes = @()
for ($i = 0; $i -lt $rawLines.Count; $i++) {
    $line = $rawLines[$i]
    $isMatch = ($patterns | Where-Object { $line -match $_ }).Count -gt 0
    $isExcluded = ($exclude | Where-Object { $line -match $_ }).Count -gt 0
    if ($isMatch -and -not $isExcluded) {
        $matchIndexes += $i
    }
}

if ($matchIndexes.Count -gt 0) {
    $filtered = @(Get-WindowedLines -Lines $rawLines -Indexes $matchIndexes -Context $Context)
} else {
    $filtered = $rawLines
}

$shownOutput = @($filtered | Select-Object -First $MaxLines)
$shownOutput

$total = $rawLines.Count
$shown = $shownOutput.Count

Write-Host ""
Write-Host "=== RESULT ==="

if ($exitCode -eq 0) {
    Write-Host "Command passed." -ForegroundColor Green
} else {
    Write-Host "Command failed with exit code $exitCode." -ForegroundColor Red
}

Write-Host "Raw lines: $total"
Write-Host "Shown lines: $shown"

if ($filtered.Count -gt $MaxLines -or $total -gt $shown) {
    Write-Host "Output was compacted/truncated. Rerun narrower command if exact details are needed." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== DIAGNOSTIC CHECK ==="

$hasFailOrError = ($shownOutput -match 'FAIL|FAILED|ERROR|Exception|error').Count -gt 0
$hasTestLine = ($shownOutput -match 'tests[\\/].*\.(php|ts|tsx|js|jsx):\d+').Count -gt 0
$hasFailedTestName = ($shownOutput -match 'FAILED\s+Tests[\\/]|FAIL\s+Tests[\\/]|FAILED\s+Tests\\|FAIL\s+Tests\\').Count -gt 0
$hasAppLine = ($shownOutput -match '(app|resources)[\\/].*\.(php|ts|tsx|js|jsx):\d+').Count -gt 0
$hasAssertionDetail = ($shownOutput -match 'Expected|Actual|Failed asserting|not identical|not equal|received \d+').Count -gt 0

function Check($Label, $Ok, $Critical = $true) {
    if ($Ok) {
        Write-Host "[OK] $Label" -ForegroundColor Green
    } elseif ($Critical) {
        Write-Host "[MISSING - CRITICAL] $Label" -ForegroundColor Red
    } else {
        Write-Host "[MISSING - OPTIONAL] $Label" -ForegroundColor Yellow
    }
}

if ($exitCode -eq 0) {
    Write-Host "No failure diagnostics needed. Command passed." -ForegroundColor Green
} else {
    Check "Has FAIL/ERROR" $hasFailOrError $true
    Check "Has failed test name" $hasFailedTestName $false
    Check "Has test file line" $hasTestLine $false
    Check "Has assertion/exception detail" $hasAssertionDetail $false
    Check "Has app/source file line" $hasAppLine $false

    if ($hasFailOrError -or $hasTestLine -or $hasAssertionDetail -or $hasAppLine) {
        Write-Host ""
        Write-Host "Compact output is likely sufficient for first-pass debugging." -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "WARNING: Compact output may not include enough failure context." -ForegroundColor Yellow
        Write-Host "Rerun with higher -MaxLines or inspect the exact failing output."
    }
}

$wasReduced = ($filtered.Count -gt $MaxLines -or $total -gt $shown)
$selection = if ($matchIndexes.Count -gt 0) {
    "kept errors/warnings/test failure markers with local context"
} elseif ($exitCode -eq 0) {
    "kept passing command output up to MaxLines"
} else {
    "no diagnostic markers found; kept raw output up to MaxLines"
}
$next = if ($exitCode -eq 0) { "continue with the next narrow workflow step" } else { "rerun narrower or raise MaxLines if diagnostics are insufficient" }
$provenance = Get-ProvenanceContext
Write-Host ""
Write-Host "=== PROVENANCE ==="
Write-Host "Repo: $($provenance.Repo)"
Write-Host "Git: $($provenance.Git)"
Write-Host "Tool: run-compact.ps1"
Write-Host "Scope: command=$Command; exit=$exitCode"
Write-Host "Excluded: dependency/build banner and deprecation noise"
Write-Host "Considered: $total raw lines"
Write-Host "Returned: $shown lines"
Write-Host "Reduction: $total -> $shown lines; compacted=$($wasReduced.ToString().ToLower())"
Write-Host "Selection: $selection"
Write-Host "Next: $next"

exit $exitCode
