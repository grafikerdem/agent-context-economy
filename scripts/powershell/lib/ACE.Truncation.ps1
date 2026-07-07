function Get-ACESmartTruncatedLines {
    param(
        [int]$Start,
        [int]$End,
        [int]$Threshold = 80,
        [int]$FirstCount = 15,
        [int]$LastCount = 10
    )
    $linesCount = $End - $Start + 1
    if ($linesCount -gt $Threshold) {
        $firstEnd = $Start + $FirstCount - 1
        $lastStart = $End - $LastCount + 1
        return @{
            IsTruncated = $true
            OmittedCount = $linesCount - ($FirstCount + $LastCount)
            FirstRange = $Start..$firstEnd
            LastRange = $lastStart..$End
        }
    } else {
        return @{
            IsTruncated = $false
            OmittedCount = 0
            FirstRange = $Start..$End
            LastRange = @()
        }
    }
}
