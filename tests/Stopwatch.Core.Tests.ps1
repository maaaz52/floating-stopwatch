$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\Stopwatch.Core.psm1') -Force

function Assert-Equal($Expected, $Actual, $Label) {
    if ($Expected -ne $Actual) {
        throw "$Label expected '$Expected' but got '$Actual'."
    }
}

Assert-Equal '00:00:00.00' (Format-StopwatchTime ([TimeSpan]::Zero)) 'zero format'
Assert-Equal '00:01:02.34' (Format-StopwatchTime ([TimeSpan]::FromMilliseconds(62340))) 'elapsed format'
Assert-Equal '27:03:04.05' (Format-StopwatchTime ([TimeSpan]::new(1, 3, 3, 4, 50))) 'total hours format'
Assert-Equal '-00:00:02.50' (Format-StopwatchTime ([TimeSpan]::FromMilliseconds(-2500)) -AllowNegative) 'negative format'
Assert-Equal 300 ([int] (ConvertFrom-DurationText '5:00').TotalSeconds) 'minutes duration'
Assert-Equal 5405 ([int] (ConvertFrom-DurationText '1:30:05').TotalSeconds) 'hours duration'
Assert-Equal 45 ([int] (ConvertFrom-DurationText '45').TotalSeconds) 'seconds duration'

$invalid = @('', 'abc', '1:70', '0', '100:00:00')
foreach ($value in $invalid) {
    $threw = $false
    try { ConvertFrom-DurationText $value | Out-Null } catch { $threw = $true }
    if (-not $threw) { throw "Expected '$value' to be rejected." }
}

Write-Host 'All core tests passed.'
