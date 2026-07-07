function Normalize-ACESymbol {
    param([string]$Value)
    $v = $Value.Trim()
    $v = $v -replace '^class\s+', ''
    $v = $v -replace '^function\s+', ''
    $v = $v -replace '^const\s+', ''
    $v = $v -replace '^interface\s+', ''
    $v = $v -replace '^type\s+', ''
    $v = $v -replace '^enum\s+', ''
    $v = $v -replace '\s*\(.*$', ''
    return $v.Trim()
}

function Count-ACEChar {
    param([AllowEmptyString()][string]$Text,[char]$Char)
    if ([string]::IsNullOrEmpty($Text)) { return 0 }
    return ($Text.ToCharArray() | Where-Object { $_ -eq $Char }).Count
}

function Detect-ACEBlockEnd {
    param([string[]]$Lines,[int]$StartLine)
    $total = $Lines.Count
    $startIndex = $StartLine - 1
    $braceDepth = 0
    $seenOpen = $false
    for ($i = $startIndex; $i -lt $total; $i++) {
        $line = $Lines[$i]
        $open = Count-ACEChar -Text $line -Char '{'
        $close = Count-ACEChar -Text $line -Char '}'
        if ($open -gt 0) { $seenOpen = $true }
        $braceDepth += $open
        $braceDepth -= $close
        if ($seenOpen -and $braceDepth -le 0) { return ($i + 1) }
        if (-not $seenOpen -and $i -gt $startIndex -and [string]::IsNullOrWhiteSpace($line)) { return ($i + 1) }
    }
    return $total
}
