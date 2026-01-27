function Invoke-CondenserAdapter {
    [CmdletBinding()]
    param (
        [string]$VirtualPath,
        [string]$Slot,
        [string]$Activity,
        [Parameter(Mandatory)][Signal]$Signal,
        [object]$Plan,
        [Parameter(Mandatory)][Signal]$ItemSignal
    )

    # ░▒▓█ SIGNAL START █▓▒░
    $opSignal = [Signal]::Start("Invoke-CondenserAdapter", $Signal) | Select-Object -Last 1

    try {
        # ░▒▓█ VALIDATE INPUT █▓▒░
        if ([string]::IsNullOrWhiteSpace($Slot)) {
            $opSignal.LogCritical("❌ Slot is required.")
            return $opSignal
        }
        if ([string]::IsNullOrWhiteSpace($Activity)) {
            $Activity = "Invoke"
            $opSignal.LogWarning("⚠️ Warning: Activity not specified, defaulted to 'Invoke'. Slot: $Slot")
        }
        if ($null -eq $ItemSignal) {
            $opSignal.LogCritical("❌ ItemSignal is required.")
            return $opSignal
        }

        # ░▒▓█ RESOLVE MAPPED CONDENSER ADAPTER █▓▒░
        $adapterPath = "%.*.#.Adapters.*.#.MappedCondenser"

        $adapterSignal = Resolve-PathFromDictionary `
            -Dictionary $Signal `
            -Path $adapterPath `
            -SignalLevel "Critical" `
        | Select-Object -Last 1

        if ($opSignal.MergeSignalAndVerifyFailure(@($adapterSignal))) {
            $opSignal.LogCritical("❌ Failed resolving MappedCondenser at path: $adapterPath")
            return $opSignal
        }

        if (-not $adapterSignal.HasResult()) {
            $opSignal.LogCritical("❌ MappedCondenser resolution returned no result (path: $adapterPath)")
            return $opSignal
        }

        $adapter = $adapterSignal.GetResult($true)
        if ($null -eq $adapter) {
            $opSignal.LogCritical("❌ MappedCondenserAdapter is null after GetResult().")
            return $opSignal
        }

        # ░▒▓█ TELEMETRY (TRACE) █▓▒░
        $vp = if ([string]::IsNullOrWhiteSpace($VirtualPath)) { "<mapped>" } else { $VirtualPath }
        $opSignal.LogInformation("🧭 Condenser route: Slot='$Slot' Activity='$Activity' VirtualPath='$vp' AdapterPath='$adapterPath'")

        # ░▒▓█ INVOKE █▓▒░
        $adapterInvokeSignal = $adapter.Invoke($Slot, $Activity, $Signal, $Plan, $ItemSignal) | Select-Object -Last 1
        if ($opSignal.MergeSignalAndVerifyFailure(@($adapterInvokeSignal))) {
            $opSignal.LogCritical("❌ Condenser Adapter invocation failed (Slot='$Slot', Activity='$Activity').")
            return $opSignal
        }

        if ($adapterInvokeSignal.HasResult()) {
            $opSignal.SetResult($adapterInvokeSignal.GetResult())
        }
        return $opSignal
    }
    catch {
        $opSignal.LogCritical("❌ Exception during Invoke-CondenserAdapter: $($_.Exception.Message)")
        return $opSignal
    }
}
