Set-StrictMode -Version Latest

function Format-StopwatchTime {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [TimeSpan] $Time,

        [switch] $AllowNegative
    )

    $negative = $Time.Ticks -lt 0
    if ($negative) {
        $Time = $Time.Negate()
    }

    $totalHours = [Math]::Floor($Time.TotalHours)
    $prefix = if ($negative -and $AllowNegative) { '-' } else { '' }
    return '{0}{1:00}:{2:00}:{3:00}.{4:00}' -f $prefix, $totalHours, $Time.Minutes, $Time.Seconds, ([Math]::Floor($Time.Milliseconds / 10))
}

function ConvertFrom-DurationText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Text
    )

    $value = $Text.Trim()
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw 'Enter a duration such as 5:00 or 1:30:00.'
    }

    $parts = $value.Split(':')
    if ($parts.Count -lt 1 -or $parts.Count -gt 3) {
        throw 'Use SS, MM:SS, or HH:MM:SS.'
    }

    $numbers = @()
    foreach ($part in $parts) {
        [int] $number = 0
        if (-not [int]::TryParse($part, [ref] $number) -or $number -lt 0) {
            throw 'Duration values must be positive whole numbers.'
        }
        $numbers += $number
    }

    switch ($numbers.Count) {
        1 { $hours = 0; $minutes = 0; $seconds = $numbers[0] }
        2 { $hours = 0; $minutes = $numbers[0]; $seconds = $numbers[1] }
        3 { $hours = $numbers[0]; $minutes = $numbers[1]; $seconds = $numbers[2] }
    }

    if ($minutes -ge 60 -and $numbers.Count -eq 3) {
        throw 'Minutes must be less than 60 in HH:MM:SS format.'
    }
    if ($seconds -ge 60 -and $numbers.Count -ge 2) {
        throw 'Seconds must be less than 60 when using colons.'
    }

    $duration = [TimeSpan]::FromSeconds(($hours * 3600L) + ($minutes * 60L) + $seconds)
    if ($duration.TotalSeconds -le 0) {
        throw 'Duration must be greater than zero.'
    }
    if ($duration.TotalHours -ge 100) {
        throw 'Duration must be less than 100 hours.'
    }

    return $duration
}

Export-ModuleMember -Function Format-StopwatchTime, ConvertFrom-DurationText
