param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Symbol,

    [int]$Context = 8,

    [int]$MaxOutputLines = 80,

    [int]$MaxBlockLines = 60,

    [switch]$Signature,

    [switch]$Body,

    [switch]$Full,

    [switch]$Summary,

    [string]$Budget
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lib\ACE.Parser.ps1")
. (Join-Path $PSScriptRoot "lib\ACE.Formatting.ps1")
. (Join-Path $PSScriptRoot "lib\ACE.Truncation.ps1")

# Resolve Context Budget
$budgetLimits = Resolve-ACEBudget -Budget $Budget -DefaultMaxLines 80 -DefaultMaxBlockLines 60
if (-not $PSBoundParameters.ContainsKey('MaxOutputLines')) {
    $MaxOutputLines = $budgetLimits.MaxOutputLines
}
if (-not $PSBoundParameters.ContainsKey('MaxBlockLines')) {
    $MaxBlockLines = $budgetLimits.MaxBlockLines
}

function Fail($Message) { Write-Host "ERROR: $Message" -ForegroundColor Red; exit 1 }
if (-not (Test-Path -LiteralPath $Path)) { Fail "File not found: $Path" }

$lines = @(Get-Content -LiteralPath $Path -Encoding UTF8)
$total = $lines.Count
$normalizedSymbol = Normalize-ACESymbol $Symbol

Write-Host ""
Write-Host "=== SYMBOL NAVIGATOR ==="
Write-Host "File: $Path"
Write-Host "Requested symbol: $Symbol"
Write-Host "Normalized symbol: $normalizedSymbol"
Write-Host "Total lines: $total"

$regexSymbol = [regex]::Escape($normalizedSymbol)
$definitionPatterns = @(
    @{ Pattern = "\bclass\s+$regexSymbol\b"; Type = "Container" },
    @{ Pattern = "\binterface\s+$regexSymbol\b"; Type = "Container" },
    @{ Pattern = "\btrait\s+$regexSymbol\b"; Type = "Container" },
    @{ Pattern = "\benum\s+$regexSymbol\b"; Type = "Container" },
    @{ Pattern = "\btype\s+$regexSymbol\b"; Type = "Container" },
    @{ Pattern = "\b(export\s+)?(async\s+)?function\s+$regexSymbol\b"; Type = "Function" },
    @{ Pattern = "\b(public|private|protected)\s+(async\s+)?function\s+$regexSymbol\b"; Type = "Function" },
    @{ Pattern = "\b(export\s+)?(const|let|var)\s+$regexSymbol\s*(:\s*[^=]+)?\s*="; Type = "Variable" }
)

$candidates = @()
for ($i = 1; $i -le $total; $i++) {
    $text = $lines[$i - 1]
    $matchedType = $null
    foreach ($p in $definitionPatterns) {
        if ($text -match $p.Pattern) {
            $matchedType = $p.Type
            break
        }
    }
    if ($matchedType) {
        $candidates += @{ Line = $i; Text = $text.Trim(); Kind = 'DEF'; DefType = $matchedType }
    }
}

if ($candidates.Count -eq 0) {
    for ($i = 1; $i -le $total; $i++) {
        $text = $lines[$i - 1]
        if ($text -match $regexSymbol) {
            $candidates += @{ Line = $i; Text = $text.Trim(); Kind = 'REF'; DefType = 'Reference' }
        }
    }
}

Write-Host ""
Write-Host "=== MATCH CANDIDATES ==="
if ($candidates.Count -eq 0) {
    Write-Host "No symbol candidates found."
    Write-Host "Try find-in-file.ps1 with a more exact keyword."
    Write-ACEProvenance -Path $Path -Symbol $Symbol -NormalizedSymbol $normalizedSymbol -TotalLines $total -CandidatesCount 0 -OutputLineCount 0 -SelectedLine "unknown" -SelectedKind "unknown" -MaxOutputLines $MaxOutputLines -Reduced $true -Next "use find-in-file with a more exact keyword"
    exit 0
}

foreach ($c in ($candidates | Select-Object -First 20)) {
    "{0,5} [{1}] {2}" -f $c.Line, $c.Kind, $c.Text
}

$selected = $candidates | Where-Object { $_.Kind -eq 'DEF' } | Select-Object -First 1
if (-not $selected) { $selected = $candidates | Select-Object -First 1 }

$blockStart = $selected.Line
$blockEnd = if ($selected.Kind -eq 'DEF') { Detect-ACEBlockEnd -Lines $lines -StartLine $blockStart } else { $selected.Line }

# Determine active Mode
$Mode = "Full"
if ($selected.Kind -eq 'DEF') {
    if ($Full) { $Mode = "Full" }
    elseif ($Body) { $Mode = "Body" }
    elseif ($Signature) { $Mode = "Signature" }
    elseif ($Summary) { $Mode = "Summary" }
    else {
        if ($selected.DefType -eq 'Container') { $Mode = "Summary" }
        else { $Mode = "Signature" }
    }
}

# Determine dynamic Context
$currentContext = $Context
if ($Context -eq 8) {
    if ($selected.Kind -eq 'DEF') {
        $currentContext = 2
    } else {
        $currentContext = 8
    }
}

# Compute start, end
$start = [Math]::Max(1, $blockStart - $currentContext)
$end = [Math]::Min($total, $blockEnd + $currentContext)

$blockLinesCount = $blockEnd - $blockStart + 1

# Extract signature
$sigLines = @()
if ($Mode -eq 'Signature') {
    for ($idx = $blockStart - 1; $idx -lt $total; $idx++) {
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
        if ($idx -ge ($blockStart + 9)) {
            break
        }
        $sigLines += [PSCustomObject]@{ Line = $idx + 1; Text = $line }
    }
}

# Extract body bounds
$bodyStart = $blockStart
if ($Mode -eq 'Body') {
    for ($idx = $blockStart - 1; $idx -lt $blockEnd; $idx++) {
        if ($lines[$idx] -match '\{') {
            $bodyStart = $idx + 1
            break
        }
    }
}
$bodyLinesCount = $blockEnd - $bodyStart + 1

# Extract summary best-effort
$extends = $null
$implements = @()
$methods = @()
$properties = @()

if ($Mode -eq 'Summary') {
    $defText = ""
    for ($idx = $blockStart - 1; $idx -lt $blockEnd; $idx++) {
        $defText += " " + $lines[$idx]
        if ($lines[$idx] -match '\{') { break }
    }

    if ($defText -match 'extends\s+([a-zA-Z0-9_\\]+)') {
        $extends = $Matches[1]
    }
    if ($defText -match 'implements\s+([a-zA-Z0-9_,\s\\]+)') {
        $implPart = $Matches[1] -replace '\{.*$', ''
        $implements = $implPart.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }

    $bodyStartLine = $blockStart
    for ($idx = $blockStart - 1; $idx -lt $blockEnd; $idx++) {
        if ($lines[$idx] -match '\{') {
            $bodyStartLine = $idx + 2
            break
        }
    }

    for ($idx = $bodyStartLine - 1; $idx -lt $blockEnd - 1; $idx++) {
        $line = $lines[$idx].Trim()
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        if ($line -match '\bfunction\s+([a-zA-Z0-9_]+)\s*\(') {
            $methods += $Matches[1] + "()"
        }
        elseif ($line -match '\b(public|private|protected)\s+(async\s+)?function\s+([a-zA-Z0-9_]+)\s*\(') {
            $methods += $Matches[3] + "()"
        }
        elseif ($line -match '^\s*(public|private|protected|async|static|readonly)*\s*([a-zA-Z0-9_]+)\s*\([^)]*\)\s*(\{|=|\b)') {
            $name = $Matches[2]
            if ($name -notin @('if', 'for', 'while', 'switch', 'catch', 'constructor', 'return', 'throw', 'super')) {
                if ($line -notmatch '=>') {
                    $methods += $name + "()"
                }
            }
        }
        elseif ($line -match '^\s*(public|private|protected|static|readonly)*\s*([a-zA-Z0-9_]+)\s*=\s*[^=]*=>') {
            $methods += $Matches[2] + "()"
        }
        elseif ($line -match '^\s*(public|private|protected|readonly|static)?\s*(\$?[a-zA-Z0-9_]+)\s*(:\s*[^;=]+)?\s*(;|=)') {
            $prop = $Matches[2]
            if ($prop -notin @('return', 'const', 'let', 'var', 'throw', 'yield', 'import', 'export', 'super', 'new')) {
                if ($line -notmatch '=>') {
                    $properties += $prop
                }
            }
        }
    }
    $methods = $methods | Select-Object -Unique
    $properties = $properties | Select-Object -Unique
}

# Calculate shown and hidden lines for metadata header
$blockLinesCount = $blockEnd - $blockStart + 1
$expectedBlockShown = 0

if ($selected.Kind -eq 'REF') {
    $blockLinesCount = 1
    $expectedBlockShown = 1
    $shown = [Math]::Min($end - $start + 1, $MaxOutputLines)
    $hidden = 0
} else {
    if ($Mode -eq 'Full') {
        $blockTruncated = ($blockLinesCount -gt 80)
        $expectedBlockShown = if ($blockTruncated) { 26 } else { $blockLinesCount }
        $preContextCount = $blockStart - $start
        $postContextCount = $end - $blockEnd
        $shown = [Math]::Min($preContextCount + $expectedBlockShown + $postContextCount, $MaxOutputLines)
        $hidden = [Math]::Max(0, $blockLinesCount - $expectedBlockShown)
    } elseif ($Mode -eq 'Body') {
        $blockTruncated = ($bodyLinesCount -gt 80)
        $expectedBlockShown = if ($blockTruncated) { 25 } else { $bodyLinesCount }
        $shown = [Math]::Min($expectedBlockShown, $MaxOutputLines)
        $hidden = [Math]::Max(0, $bodyLinesCount - $expectedBlockShown)
    } elseif ($Mode -eq 'Signature') {
        $expectedBlockShown = [Math]::Min($sigLines.Count, $blockLinesCount)
        $shown = [Math]::Min($sigLines.Count, $MaxOutputLines)
        $hidden = [Math]::Max(0, $blockLinesCount - $expectedBlockShown)
    } else { # Summary
        $shown = 0
        $hidden = $blockLinesCount
    }
}

# Metadata Header (always shown)
Write-ACEMetadataHeader -Title "=== SELECTED SYMBOL WINDOW ===" -Symbol $Symbol -Kind $($selected.Kind) -BlockLines $blockLinesCount -Shown $shown -Hidden $hidden -Mode $Mode -Path $Path -IsRef ($selected.Kind -eq 'REF')

if ($Mode -eq 'Summary') {
    $hasSummary = $extends -or ($implements.Count -gt 0) -or ($methods.Count -gt 0) -or ($properties.Count -gt 0)
    if (-not $hasSummary) {
        Write-Host ""
        Write-Host "[summary unavailable; use -Full or -Body for source]"
    } else {
        Write-Host ""
        Write-Host "=== SYMBOL SUMMARY ==="
        Write-Host "Type: $($selected.DefType)"
        if ($extends) { Write-Host "Extends: $extends" }
        if ($implements.Count -gt 0) { Write-Host "Implements: $($implements -join ', ')" }
        Write-Host ""

        $printedCount = 0
        $limitExceeded = $false

        if ($methods.Count -gt 0) {
            if ($printedCount -lt $MaxOutputLines) {
                Write-Host "Methods"
                Write-Host "-------"
                $printedCount += 2
            }
            foreach ($m in $methods) {
                if ($printedCount -lt $MaxOutputLines) {
                    Write-Host "- $m"
                    $printedCount++
                } else {
                    $limitExceeded = $true
                    break
                }
            }
            Write-Host ""
        }

        if (-not $limitExceeded -and $properties.Count -gt 0) {
            if ($printedCount -lt $MaxOutputLines) {
                Write-Host "Properties"
                Write-Host "----------"
                $printedCount += 2
            }
            foreach ($p in $properties) {
                if ($printedCount -lt $MaxOutputLines) {
                    Write-Host "- $p"
                    $printedCount++
                } else {
                    $limitExceeded = $true
                    break
                }
            }
            Write-Host ""
        }

        if ($limitExceeded) {
            Write-Host "[truncated: output exceeded MaxOutputLines]"
        }
    }
} else {
    $printedCount = 0
    $limitExceeded = $false
    $blockTruncated = $false

    if ($Mode -eq 'Full') {
        Write-Host ""
        Write-Host "=== SOURCE ==="

        # Pre-context
        for ($i = $start; $i -lt $blockStart; $i++) {
            if ($printedCount -lt $MaxOutputLines) {
                $prefix = if ($i -eq $selected.Line) { ">" } else { " " }
                "{0} {1,5}: {2}" -f $prefix, $i, $lines[$i - 1]
                $printedCount++
            } else {
                $limitExceeded = $true
                break
            }
        }

        # Block
        if (-not $limitExceeded) {
            $truncResult = Get-ACESmartTruncatedLines -Start $blockStart -End $blockEnd -FirstCount 16 -LastCount 10
            if ($truncResult.IsTruncated) {
                $blockTruncated = $true
                foreach ($i in $truncResult.FirstRange) {
                    if ($printedCount -lt $MaxOutputLines) {
                        $prefix = if ($i -eq $selected.Line) { ">" } else { " " }
                        "{0} {1,5}: {2}" -f $prefix, $i, $lines[$i - 1]
                        $printedCount++
                    } else {
                        $limitExceeded = $true
                        break
                    }
                }
                if (-not $limitExceeded) {
                    if ($printedCount -lt $MaxOutputLines) {
                        "      ... [{0} lines omitted] ..." -f $truncResult.OmittedCount
                        $printedCount++
                    } else {
                        $limitExceeded = $true
                    }
                }
                if (-not $limitExceeded) {
                    foreach ($i in $truncResult.LastRange) {
                        if ($printedCount -lt $MaxOutputLines) {
                            $prefix = if ($i -eq $selected.Line) { ">" } else { " " }
                            "{0} {1,5}: {2}" -f $prefix, $i, $lines[$i - 1]
                            $printedCount++
                        } else {
                            $limitExceeded = $true
                            break
                        }
                    }
                }
            } else {
                foreach ($i in $truncResult.FirstRange) {
                    if ($printedCount -lt $MaxOutputLines) {
                        $prefix = if ($i -eq $selected.Line) { ">" } else { " " }
                        "{0} {1,5}: {2}" -f $prefix, $i, $lines[$i - 1]
                        $printedCount++
                    } else {
                        $limitExceeded = $true
                        break
                    }
                }
            }
        }

        # Post-context
        if (-not $limitExceeded) {
            for ($i = $blockEnd + 1; $i -le $end; $i++) {
                if ($printedCount -lt $MaxOutputLines) {
                    $prefix = if ($i -eq $selected.Line) { ">" } else { " " }
                    "{0} {1,5}: {2}" -f $prefix, $i, $lines[$i - 1]
                    $printedCount++
                } else {
                    $limitExceeded = $true
                    break
                }
            }
        }
    }
    elseif ($Mode -eq 'Body') {
        Write-Host ""
        Write-Host "=== SOURCE (BODY) ==="

        $truncResult = Get-ACESmartTruncatedLines -Start $bodyStart -End $blockEnd -FirstCount 15 -LastCount 10
        if ($truncResult.IsTruncated) {
            $blockTruncated = $true
            foreach ($i in $truncResult.FirstRange) {
                if ($printedCount -lt $MaxOutputLines) {
                    $prefix = if ($i -eq $selected.Line) { ">" } else { " " }
                    "{0} {1,5}: {2}" -f $prefix, $i, $lines[$i - 1]
                    $printedCount++
                } else {
                    $limitExceeded = $true
                    break
                }
            }
            if (-not $limitExceeded) {
                if ($printedCount -lt $MaxOutputLines) {
                    "      ... [{0} lines omitted] ..." -f $truncResult.OmittedCount
                    $printedCount++
                } else {
                    $limitExceeded = $true
                }
            }
            if (-not $limitExceeded) {
                foreach ($i in $truncResult.LastRange) {
                    if ($printedCount -lt $MaxOutputLines) {
                        $prefix = if ($i -eq $selected.Line) { ">" } else { " " }
                        "{0} {1,5}: {2}" -f $prefix, $i, $lines[$i - 1]
                        $printedCount++
                    } else {
                        $limitExceeded = $true
                        break
                    }
                }
            }
        } else {
            foreach ($i in $truncResult.FirstRange) {
                if ($printedCount -lt $MaxOutputLines) {
                    $prefix = if ($i -eq $selected.Line) { ">" } else { " " }
                    "{0} {1,5}: {2}" -f $prefix, $i, $lines[$i - 1]
                    $printedCount++
                } else {
                    $limitExceeded = $true
                    break
                }
            }
        }
    }
    elseif ($Mode -eq 'Signature') {
        Write-Host ""
        Write-Host "=== SOURCE (SIGNATURE) ==="

        foreach ($item in $sigLines) {
            if ($printedCount -lt $MaxOutputLines) {
                $prefix = if ($item.Line -eq $selected.Line) { ">" } else { " " }
                "{0} {1,5}: {2}" -f $prefix, $item.Line, $item.Text
                $printedCount++
            } else {
                $limitExceeded = $true
                break
            }
        }
    }

    if ($blockTruncated) {
        if ($Mode -eq "Body") {
            Write-Host "[truncated: body exceeded MaxBlockLines]"
        } else {
            Write-Host "[truncated: block exceeded MaxBlockLines]"
        }
    }
    if ($limitExceeded) {
        Write-Host "[truncated: output exceeded MaxOutputLines]"
    }
}

Write-Host ""
Write-Host "=== GUIDANCE ==="
Write-Host "Use this symbol window first."
Write-Host "If related imports/types/state are missing, read one nearby window with read-window.ps1 rather than dumping the whole file."
Write-Host "If the selected match is a reference, rerun with a more exact definition symbol."

$nextCmd = Get-ACENextCommand -Tool "read-symbol" -Path $Path -Symbol $Symbol -Mode $Mode -Kind $selected.Kind -IsTruncated ($blockTruncated -or $limitExceeded) -SelectedLine $selected.Line -DefType $selected.DefType
Write-ACEProvenance -Path $Path -Symbol $Symbol -NormalizedSymbol $normalizedSymbol -TotalLines $total -CandidatesCount $candidates.Count -OutputLineCount $shown -SelectedLine $selected.Line -SelectedKind $selected.Kind -MaxOutputLines $MaxOutputLines -Reduced ($shown -lt $total -or $candidates.Count -gt 20) -Next $nextCmd -ToolName "read-symbol.ps1"
