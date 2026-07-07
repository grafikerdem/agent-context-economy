param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [int]$MaxLines = 200,

    [switch]$Summary,

    [switch]$Signature,

    [switch]$Full,

    [string]$Budget
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lib/ACE.Parser.ps1")
. (Join-Path $PSScriptRoot "lib/ACE.Formatting.ps1")
. (Join-Path $PSScriptRoot "lib/ACE.Truncation.ps1")

# Resolve Context Budget
$budgetLimits = Resolve-ACEBudget -Budget $Budget -DefaultMaxLines 200 -DefaultMaxBlockLines 200
if (-not $PSBoundParameters.ContainsKey('MaxLines')) {
    $MaxLines = $budgetLimits.MaxOutputLines
}

function Fail($Message) { Write-Host "ERROR: $Message" -ForegroundColor Red; exit 1 }
if (-not (Test-Path -LiteralPath $Path)) { Fail "File not found: $Path" }

$extension = [System.IO.Path]::GetExtension($Path).ToLower()
$codeExtensions = @('.php', '.ts', '.js', '.tsx', '.py', '.go', '.cs', '.java', '.cpp', '.h', '.rb', '.rs', '.swift')

$isCodeFile = $extension -in $codeExtensions

# Determine active Mode
$Mode = "Full"
if ($isCodeFile) {
    if ($Full) { $Mode = "Full" }
    elseif ($Signature) { $Mode = "Signature" }
    elseif ($Summary) { $Mode = "Summary" }
    else { $Mode = "Summary" } # default for code files
}

$content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
$lines = @($content -split "`r?`n")
$total = $lines.Count
$limitExceeded = $false

# Regexes for parsing definitions
$containerRegex = '^\s*(export\s+)?(class|interface|trait|enum|type)\s+([a-zA-Z0-9_]+)'
$functionRegex = '^\s*(export\s+)?(async\s+)?function\s+([a-zA-Z0-9_]+)'
$phpMethodRegex = '^\s*(public|private|protected)\s+(static\s+)?(async\s+)?function\s+([a-zA-Z0-9_]+)'
$jsMethodRegex = '^\s*(async\s+)?([a-zA-Z0-9_]+)\s*\([^)]*\)\s*(\{|=|\b)'
$varRegex = '^\s*(export\s+)?(const|let|var)\s+([a-zA-Z0-9_]+)\s*(:\s*[^=]+)?\s*='

$definitions = @()

for ($i = 1; $i -le $total; $i++) {
    $line = $lines[$i - 1].Trim()
    if ([string]::IsNullOrWhiteSpace($line)) { continue }

    if ($line -match $containerRegex) {
        $definitions += @{ Line = $i; Text = $line; Name = $Matches[3]; Kind = 'Container'; Type = $Matches[2] }
    }
    elseif ($line -match $phpMethodRegex) {
        $definitions += @{ Line = $i; Text = $line; Name = $Matches[4] + "()"; Kind = 'Method'; Type = 'function' }
    }
    elseif ($line -match $functionRegex) {
        $definitions += @{ Line = $i; Text = $line; Name = $Matches[3] + "()"; Kind = 'Method'; Type = 'function' }
    }
    elseif ($line -match $jsMethodRegex) {
        $name = $Matches[2]
        if ($name -notin @('if', 'for', 'while', 'switch', 'catch', 'constructor', 'return', 'throw', 'super', 'new', 'import', 'export')) {
            if ($line -notmatch '=>') {
                $definitions += @{ Line = $i; Text = $line; Name = $name + "()"; Kind = 'Method'; Type = 'method' }
            }
        }
    }
    elseif ($line -match $varRegex) {
        $name = $Matches[3]
        if ($name -notin @('return', 'const', 'let', 'var', 'throw', 'yield', 'import', 'export', 'super', 'new')) {
            $definitions += @{ Line = $i; Text = $line; Name = $name; Kind = 'Variable'; Type = 'variable' }
        }
    }
}

# Extract signatures if needed
$signatures = @()
if ($Mode -eq 'Signature') {
    foreach ($def in $definitions) {
        $sigLines = @()
        $startIdx = $def.Line - 1
        for ($idx = $startIdx; $idx -lt $total; $idx++) {
            $line = $lines[$idx]
            if ($line -match '\{') {
                $clean = $line -replace '\{.*$', ''
                $sigLines += [PSCustomObject]@{ Line = $idx + 1; Text = $clean }
                break
            } elseif ($line -match ';') {
                $clean = $line -replace ';.*$', ''
                $sigLines += [PSCustomObject]@{ Line = $idx + 1; Text = $clean }
                break
            }
            if ($idx -ge ($startIdx + 4)) { # max 5 lines
                $sigLines += [PSCustomObject]@{ Line = $idx + 1; Text = $line }
                break
            }
            $sigLines += [PSCustomObject]@{ Line = $idx + 1; Text = $line }
        }
        $signatures += @{ Def = $def; Lines = $sigLines }
    }
}

# Compute shown/hidden counts
$shown = 0
$hidden = 0

if ($Mode -eq 'Full') {
    $shown = [Math]::Min($total, $MaxLines)
    $hidden = [Math]::Max(0, $total - $shown)
} elseif ($Mode -eq 'Signature') {
    $sigCount = 0
    foreach ($sig in $signatures) {
        $sigCount += $sig.Lines.Count
    }
    $shown = [Math]::Min($sigCount, $MaxLines)
    $hidden = [Math]::Max(0, $total - $shown)
} else {
    $shown = 0
    $hidden = $total
}

# Metadata Header (always shown)
Write-ACEMetadataHeader -Title "=== UTF-8 TEXT READ ===" -Symbol "" -Kind "" -BlockLines 0 -Shown $shown -Hidden $hidden -Mode $Mode -Path $Path -IsRef $false

if ($Mode -eq 'Summary') {
    if ($definitions.Count -eq 0) {
        Write-Host ""
        Write-Host "[summary unavailable; use -Full for source]"
    } else {
        Write-Host ""
        Write-Host "=== FILE SUMMARY ==="
        
        $containers = $definitions | Where-Object { $_.Kind -eq 'Container' }
        $methods = $definitions | Where-Object { $_.Kind -eq 'Method' }
        $variables = $definitions | Where-Object { $_.Kind -eq 'Variable' }
        
        $printedCount = 0
        $limitExceeded = $false
        
        if ($containers.Count -gt 0) {
            if ($printedCount -lt $MaxLines) {
                Write-Host "Containers:"
                $printedCount++
            }
            foreach ($c in $containers) {
                if ($printedCount -lt $MaxLines) {
                    Write-Host "  - $($c.Type): $($c.Name) (line $($c.Line))"
                    $printedCount++
                } else {
                    $limitExceeded = $true
                    break
                }
            }
            if (-not $limitExceeded -and $printedCount -lt $MaxLines) {
                Write-Host ""
                $printedCount++
            }
        }
        
        if (-not $limitExceeded -and $methods.Count -gt 0) {
            if ($printedCount -lt $MaxLines) {
                Write-Host "Methods/Functions:"
                $printedCount++
            }
            foreach ($m in $methods) {
                if ($printedCount -lt $MaxLines) {
                    Write-Host "  - $($m.Name) (line $($m.Line))"
                    $printedCount++
                } else {
                    $limitExceeded = $true
                    break
                }
            }
            if (-not $limitExceeded -and $printedCount -lt $MaxLines) {
                Write-Host ""
                $printedCount++
            }
        }
        
        if (-not $limitExceeded -and $variables.Count -gt 0) {
            if ($printedCount -lt $MaxLines) {
                Write-Host "Exports/Variables:"
                $printedCount++
            }
            foreach ($v in $variables) {
                if ($printedCount -lt $MaxLines) {
                    Write-Host "  - $($v.Name) (line $($v.Line))"
                    $printedCount++
                } else {
                    $limitExceeded = $true
                    break
                }
            }
            if (-not $limitExceeded -and $printedCount -lt $MaxLines) {
                Write-Host ""
                $printedCount++
            }
        }
        
        if ($limitExceeded) {
            Write-Host "[truncated: output exceeded MaxLines]"
        }
    }
}
elseif ($Mode -eq 'Signature') {
    if ($definitions.Count -eq 0) {
        Write-Host ""
        Write-Host "[signature unavailable; use -Full for source]"
    } else {
        Write-Host ""
        Write-Host "=== FILE SIGNATURES ==="
        
        $printedCount = 0
        $limitExceeded = $false
        
        foreach ($sig in $signatures) {
            if ($limitExceeded) { break }
            
            foreach ($item in $sig.Lines) {
                if ($printedCount -lt $MaxLines) {
                    "{0,5}: {1}" -f $item.Line, $item.Text
                    $printedCount++
                } else {
                    $limitExceeded = $true
                    break
                }
            }
            if (-not $limitExceeded -and $printedCount -lt $MaxLines) {
                Write-Host ""
                $printedCount++
            }
        }
        
        if ($limitExceeded) {
            Write-Host "[truncated: output exceeded MaxLines]"
        }
    }
}
else {
    Write-Host ""
    Write-Host "=== SOURCE ==="
    
    $printedCount = 0
    $limitExceeded = $false
    for ($i = 0; $i -lt $total; $i++) {
        if ($printedCount -lt $MaxLines) {
            $lines[$i]
            $printedCount++
        } else {
            $limitExceeded = $true
            break
        }
    }
    
    if ($limitExceeded) {
        Write-Host ""
        Write-Host "=== TRUNCATED ===" -ForegroundColor Yellow
        Write-Host "[truncated: output exceeded MaxLines]"
    }
}

$nextCmd = Get-ACENextCommand -Tool "read-text" -Path $Path -Symbol "" -Mode $Mode -Kind "" -IsTruncated $limitExceeded -SelectedLine 1 -DefType ""
Write-Host ""
Write-Host "=== GUIDANCE ==="
Write-Host "Next recommended:"
Write-Host "  $nextCmd"
