function Invoke-FormatJson {
    param (
        [Parameter(Mandatory)][string]$Path,
        [object]$Plan
    )

    $opSignal = [Signal]::Start("Invoke-TokenFormatterJson") | Select-Object -Last 1

    try {
        $json = $Path | ConvertFrom-Json -Depth 100 
        $opSignal.SetResult($json)

        $opSignal.LogInformation("✅ Json Created from Path")
    }
    catch {
        $opSignal.LogCritical("🔥 Exception in Invoke-TokenFormatterJson: $_")
    }

    return $opSignal
}
