function Get-ACEProvenanceContext {
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

function Write-ACEProvenance {
    param(
        [string]$Path,
        [string]$Symbol,
        [string]$NormalizedSymbol,
        [int]$TotalLines,
        [int]$CandidatesCount,
        [int]$OutputLineCount,
        [string]$SelectedLine,
        [string]$SelectedKind,
        [int]$MaxOutputLines,
        [bool]$Reduced,
        [string]$Next,
        [string]$ToolName = "read-symbol.ps1"
    )
    $provenance = Get-ACEProvenanceContext
    Write-Host ""
    Write-Host "=== PROVENANCE ==="
    Write-Host "Repo: $($provenance.Repo)"
    Write-Host "Git: $($provenance.Git)"
    Write-Host "Tool: $ToolName"
    Write-Host "Scope: path=$Path; requested=$Symbol; normalized=$NormalizedSymbol"
    Write-Host "Excluded: source outside selected symbol window; candidates after first 20"
    Write-Host "Considered: $TotalLines lines; $CandidatesCount candidates"
    Write-Host "Returned: $OutputLineCount source lines; selected=$SelectedLine/$SelectedKind"
    Write-Host "Reduction: max-output=$MaxOutputLines; compacted=$($Reduced.ToString().ToLower())"
    Write-Host "Selection: definition preferred over reference; local symbol block selected"
    Write-Host "Next: $Next"
}

function Write-ACEMetadataHeader {
    param(
        [string]$Title,
        [string]$Symbol,
        [string]$Kind,
        [int]$BlockLines,
        [int]$Shown,
        [int]$Hidden,
        [string]$Mode,
        [string]$Path,
        [bool]$IsRef
    )
    Write-Host ""
    Write-Host $Title
    
    if ($Title -eq "=== UTF-8 TEXT READ ===") {
        Write-Host "File         : $Path"
        Write-Host "Mode         : $Mode"
        Write-Host "Source shown : $Shown lines"
        if ($Mode -eq 'Summary') {
            Write-Host "Summary      : yes"
        } elseif ($Mode -eq 'Signature') {
            Write-Host "Signature    : yes"
        } else {
            Write-Host "Summary      : no"
        }
        Write-Host "Hidden       : $Hidden source lines"
    } else {
        Write-Host "Symbol       : $Symbol"
        Write-Host "Kind         : $Kind"
        if ($IsRef) {
            Write-Host "Source shown : $Shown lines"
            Write-Host "Hidden       : unknown"
        } else {
            Write-Host "Block        : $BlockLines lines"
            if ($Mode -eq 'Summary') {
                Write-Host "Source shown : 0 lines"
                Write-Host "Summary      : yes"
                Write-Host "Hidden       : $Hidden source lines"
            } elseif ($Mode -eq 'Signature') {
                Write-Host "Signature    : yes"
                Write-Host "Source shown : $Shown lines"
                Write-Host "Hidden       : $Hidden source lines"
            } else {
                Write-Host "Summary      : no"
                Write-Host "Source shown : $Shown lines"
                Write-Host "Hidden       : $Hidden source lines"
            }
        }
    }
}

function Resolve-ACEBudget {
    param(
        [string]$Budget,
        [int]$DefaultMaxLines = 80,
        [int]$DefaultMaxBlockLines = 60
    )
    if ([string]::IsNullOrWhiteSpace($Budget)) {
        return @{
            MaxOutputLines = $DefaultMaxLines
            MaxBlockLines = $DefaultMaxBlockLines
        }
    }
    
    switch ($Budget.ToLower()) {
        "small" {
            return @{
                MaxOutputLines = 30
                MaxBlockLines = 20
            }
        }
        "large" {
            return @{
                MaxOutputLines = 250
                MaxBlockLines = 200
            }
        }
        # default / medium
        default {
            return @{
                MaxOutputLines = 100
                MaxBlockLines = 80
            }
        }
    }
}

function Get-ACENextCommand {
    param(
        [string]$Tool,       # "read-symbol" or "read-text"
        [string]$Path,
        [string]$Symbol,
        [string]$Mode,
        [string]$Kind,       # "DEF" or "REF"
        [bool]$IsTruncated,
        [int]$SelectedLine,
        [string]$DefType
    )
    
    $file = [System.IO.Path]::GetFileName($Path)
    
    if ($Tool -eq "read-symbol") {
        if ($Kind -eq 'REF') {
            return "read-window.ps1 -Path $file -Line $SelectedLine -Context 8"
        }
        
        switch ($Mode) {
            "Summary" {
                return "read-symbol.ps1 -Path $file -Symbol $Symbol -Signature -Budget Small"
            }
            "Signature" {
                return "read-symbol.ps1 -Path $file -Symbol $Symbol -Body -Budget Medium"
            }
            "Body" {
                if ($IsTruncated) {
                    return "read-symbol.ps1 -Path $file -Symbol $Symbol -Full -Budget Large"
                } else {
                    return "read-window.ps1 -Path $file -Line $SelectedLine -Context 8"
                }
            }
            "Full" {
                if ($IsTruncated) {
                    return "read-symbol.ps1 -Path $file -Symbol $Symbol -Full -Budget Large"
                } else {
                    return "read-window.ps1 -Path $file -Line $SelectedLine -Context 30"
                }
            }
        }
    } else {
        # read-text
        switch ($Mode) {
            "Summary" {
                return "read-text.ps1 -Path $file -Signature -Budget Medium"
            }
            "Signature" {
                return "read-text.ps1 -Path $file -Full -Budget Medium"
            }
            "Full" {
                if ($IsTruncated) {
                    return "read-text.ps1 -Path $file -Full -Budget Large"
                } else {
                    return "read-window.ps1 -Path $file -Line 1 -Context 30"
                }
            }
        }
    }
    return "read-window.ps1 -Path $file -Line 1"
}
