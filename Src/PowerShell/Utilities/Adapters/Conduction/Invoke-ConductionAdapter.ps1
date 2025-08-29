function Invoke-StorageAdapter {
    [CmdletBinding()]
    param (
        [Signal]$MappedAdapterSignal,
        [Conduit]$Conduit,
        [Conductor]$Conductor,
        [string]$Path,
        [string]$Slot
#        [object]$Plan  # Typically a small PSObject or Phase class in the future



    )

    if ( $Conduit -and -not $Conduit.IsRunning) {
        throw "Conduction is not running. Cannot invoke Phase."
    }

    $opSignal = [Signal]::Start("Invoke-TokenStorage", $Conductor) | Select-Object -Last 1


    try {
        if ([string]::IsNullOrWhiteSpace($Path)) {
            $opSignal.LogWarning("⚠️ Path is empty. Nothing to resolve.")
            return $opSignal
        }

        $adapterPath = "*.#.$Slot.@"
        $adapterSignal = Resolve-PathFromDictionary -Dictionary $MappedAdapterSignal -Path $adapterPath | Select-Object -Last 1
        if ($opSignal.MergeSignalAndVerifyFailure($adapterSignal)) {
            $opSignal.LogCritical("⚠️ Adapter path '$adapterPath' not found in Conductor.")
            return $opSignal
        }
        
        $adapter = $adapterSignal.GetResult()
        
        $resolvedPathSignal = Resolve-PathWithExtensionFromPath -Signal $opSignal -Path $Path | Select-Object -Last 1
        
        if ($opSignal.MergeSignalAndVerifyFailure($resolvedPathSignal)) {
            $opSignal.LogCritical("⚠️ Could not resolve path with extension for '$Path'.")
            return $opSignal
        } 
        
        $Path = $resolvedPathSignal.GetResult()

        $adapterIvokeSignal = $adapter.Invoke($Path) | Select-Object -Last 1
        if ($opSignal.MergeSignalAndVerifyFailure($adapterIvokeSignal)) {
            $opSignal.LogCritical("⚠️ Adapter failed to resolve path '$Path' with slot '$Slot'.")
            return $opSignal
        }
        else {
            $opSignal.SetResult($adapterIvokeSignal.GetResult())
        }

    }
    catch {
        $opSignal.LogCritical("🔥 Exception during Invoke-TokenStorage: $_")
    }

    return $opSignal}

