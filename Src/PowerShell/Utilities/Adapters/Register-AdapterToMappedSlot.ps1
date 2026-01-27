function Register-AdapterToMappedSlot {
    param (
        [Signal]$ConductorJacketSignal,
        [Signal]$Signal,

        [Parameter(Mandatory)]
        [object]$Adapter
    )

    #Currently treating these as interchangeable, but will want to limit down to one or the other eventually.
    if ($null -eq $ConductorJacketSignal) {
        $ConductorJacketSignal = $Signal
    }
    
    $opSignal = [Signal]::Start("Register-AdapterToMappedSlot") | Select-Object -Last 1

    try {
        # ░▒▓█ UNWRAP SIGNAL IF NECESSARY █▓▒░
        $resolvedAdapter = if ($Adapter -is [Signal]) {
            $Adapter.GetResult()
        } else {
            $Adapter
        }

        # ░▒▓█ RESOLVE KIND FROM JACKET █▓▒░
        $kindSignal = Resolve-PathFromDictionary -Dictionary $resolvedAdapter -Path "$.%.@.Kind" | Select-Object -Last 1
        if ($opSignal.MergeSignalAndVerifyFailure($kindSignal)) {
            return $opSignal.LogCritical("❌ Adapter does not contain a resolvable '$.%.@.Kind' path.")
        }

        $kind = $kindSignal.GetResult()
        if ([string]::IsNullOrWhiteSpace($kind)) {
            return $opSignal.LogCritical("❌ Adapter $.%.@.Kind is empty or null.")
        }

        # ░▒▓█ RESOLVE KIND FROM JACKET █▓▒░
        $slotSignal = Resolve-PathFromDictionary -Dictionary $resolvedAdapter -Path "$.%.@.Slot" | Select-Object -Last 1
        if ($opSignal.MergeSignalAndVerifyFailure($slotSignal)) {
            return $opSignal.LogCritical("❌ Adapter does not contain a resolvable '$.%.@.Slot' path.")
        }

        $slot = $slotSignal.GetResult()
        if ([string]::IsNullOrWhiteSpace($slot)) {
            return $opSignal.LogCritical("❌ Adapter $.%.@.Slot is empty or null.")
        }

        # ░▒▓█ RESOLVE MAPPED ATTACHMENT CONTAINER █▓▒░
        $mappedPath = "*.#.Adapters.*.#.Mapped$kind"
        $mappedSignal = Resolve-PathFromDictionary -Dictionary $ConductorJacketSignal -Path $mappedPath | Select-Object -Last 1
        if ($opSignal.MergeSignalAndVerifyFailure($mappedSignal)) {
            return $opSignal.LogCritical("❌ MappedAdapter path '$mappedPath' not found in Conductor.")
        }

        $mappedAdapterContainer = $mappedSignal.GetResult($true)

        if ($null -eq $mappedAdapterContainer) {
            return $opSignal.LogCritical("❌ MappedAdapter container at '$mappedPath' is null.")
        }

        # ░▒▓█ REGISTER ATTACHMENT █▓▒░
        $registerSignal = $mappedAdapterContainer.RegisterAdapter($resolvedAdapter, $slot) | Select-Object -Last 1
        if ($opSignal.MergeSignalAndVerifySuccess($registerSignal)) {
            $opSignal.LogInformation("✅ Adapter registered to MappedAdapter slot '$kind'.")
        } else {
            $opSignal.LogWarning("⚠️ Adapter registration returned warning or soft failure.")
        }

        # ░▒▓█ RESULT █▓▒░
        $opSignal.SetResult($mappedAdapterContainer)
    }
    catch {
        $opSignal.LogCritical("🔥 Unhandled exception during MappedAdapter registration: $($_.Exception.Message)")
    }

    # ░▒▓█ OPTIONAL: MERGE INTO CONDUCTOR CONTROL SIGNAL █▓▒░
    if ($Conductor -and $Conductor.ControlSignal) {
        $Conductor.ControlSignal.MergeSignal($opSignal)
    }

    return $opSignal
}

function Register-AdapterToMappedSlot-NonGrid {
    param (
        [Parameter(Mandatory)]
        [Conductor]$Conductor,

        [Parameter(Mandatory)]
        [object]$Adapter
    )

    $opSignal = [Signal]::Start("Register-AdapterToMappedSlot") | Select-Object -Last 1

    try {
        # ░▒▓█ UNWRAP SIGNAL IF NECESSARY █▓▒░
        $resolvedAdapter = if ($Adapter -is [Signal]) {
            $Adapter.GetResult()
        } else {
            $Adapter
        }

        # ░▒▓█ RESOLVE KIND FROM JACKET █▓▒░
        $kindSignal = Resolve-PathFromDictionary -Dictionary $resolvedAdapter -Path "$.%.@.Kind" | Select-Object -Last 1
        if ($opSignal.MergeSignalAndVerifyFailure($kindSignal)) {
            return $opSignal.LogCritical("❌ Adapter does not contain a resolvable 'Jacket.Kind' path.")
        }

        $kind = $kindSignal.GetResult()
        if ([string]::IsNullOrWhiteSpace($kind)) {
            return $opSignal.LogCritical("❌ Adapter Jacket.Kind is empty or null.")
        }

        # ░▒▓█ RESOLVE MAPPED ATTACHMENT CONTAINER █▓▒░
        $mappedPath = "$.*.#.Adapters.*.#.Mapped$($kind)"
        $mappedSignal = Resolve-PathFromDictionary -Dictionary $Conductor -Path $mappedPath | Select-Object -Last 1
        if ($opSignal.MergeSignalAndVerifyFailure($mappedSignal)) {
            return $opSignal.LogCritical("❌ MappedAdapter path '$mappedPath' not found in Conductor.")
        }

        $mappedAdapterContainer = $mappedSignal.GetResult()
        if ($null -eq $mappedAdapterContainer) {
            return $opSignal.LogCritical("❌ MappedAdapter container at '$mappedPath' is null.")
        }

        # ░▒▓█ REGISTER ATTACHMENT █▓▒░
        $registerSignal = $mappedAdapterContainer.RegisterAdapter($resolvedAdapter) | Select-Object -Last 1
        if ($opSignal.MergeSignalAndVerifySuccess($registerSignal)) {
            $opSignal.LogInformation("✅ Adapter registered to MappedAdapter slot '$kind'.")
        } else {
            $opSignal.LogWarning("⚠️ Adapter registration returned warning or soft failure.")
        }

        # ░▒▓█ RESULT █▓▒░
        $opSignal.SetResult($mappedAdapterContainer)
    }
    catch {
        $opSignal.LogCritical("🔥 Unhandled exception during MappedAdapter registration: $($_.Exception.Message)")
    }

    # ░▒▓█ OPTIONAL: MERGE INTO CONDUCTOR CONTROL SIGNAL █▓▒░
    if ($Conductor -and $Conductor.ControlSignal) {
        $Conductor.ControlSignal.MergeSignal($opSignal)
    }

    return $opSignal
}
