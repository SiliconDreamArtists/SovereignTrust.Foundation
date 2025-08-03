function Invoke-MappedTokenAdapter {
    [CmdletBinding()]
    param (
        [MappedTokenAdapter]$MappedAdapter,
        [Conduit]$Conduit,
        [Conductor]$Conductor,
        [object]$Path,
        [object]$Plan  # Typically a small PSObject or Phase class in the future
    )

    $opSignal = [Signal]::Start("Invoke-MappedTokenAdapter") | Select-Object -Last 1

    try {
        if (-not $MappedAdapter) {
            return $opSignal.LogCritical("❌ MappedAdapter is null.")
        }

        if (-not $Path -or -not ($Path -is [string])) {
            return $opSignal.LogCritical("❌ Invalid or missing path: $Path")
        }

        # Remove enclosing [/] if present
        $trimmed = $Path -replace '^\[\/|\]$', ''

        # Split on period
        $parts = $trimmed -split '\.'

        if ($parts.Count -eq 0) {
            return $opSignal.LogWarning("⚠️ No valid path parts found in: $Path")
        }

        $firstKey = $parts[0]

        # Look in the MappedAdapter Signal's graph for the corresponding key
        $graph = $MappedAdapter.Signal.GetPointer()
        $lookupPath = "#.$firstKey"

        $adapterSignal = Resolve-PathFromDictionary -Dictionary $graph -Path $lookupPath | Select-Object -Last 1
        $opSignal.MergeSignal($adapterSignal)

        if ($adapterSignal.Failure()) {
            return $opSignal.LogWarning("⚠️ Could not resolve adapter for key: $firstKey")
        }

        $adapter = $adapterSignal

        while ($adapter -is [Signal])
        {
            $adapter = $adapter.GetResult()
        }

        if ($adapter -and ($adapter | Get-Member -Name "Invoke")) {
            $invokeSignal = $adapter.Invoke($trimmed, $Plan) | Select-Object -Last 1
            $opSignal.MergeSignal($invokeSignal)

            if ($invokeSignal.Success()) {
                $opSignal.SetResult($invokeSignal.GetResult())
                $opSignal.LogInformation("✅ MappedTokenAdapter successfully invoked path: $trimmed")
            }
            else {
                $opSignal.LogWarning("⚠️ Invocation failed for path: $trimmed")
            }
        }
        else {
            $opSignal.LogWarning("⚠️ Resolved adapter for '$firstKey' does not implement Invoke().")
        }
    }
    catch {
        $opSignal.LogCritical("🔥 Exception in Invoke-MappedTokenAdapter: $($_.Exception.Message)")
    }

    return $opSignal
}
