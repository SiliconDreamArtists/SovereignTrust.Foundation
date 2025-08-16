function Resolve-ConductorAdapters {
    param (
        [Parameter(Mandatory = $true)]
        [Signal]$Signal,

        [Parameter(Mandatory)]
        [object]$Conductor
    )

    $opSignal = [Signal]::Start("ResolveConductorAdapters") | Select-Object -Last 1

    try {
        # ░▒▓█ MEMORY PREPARATION █▓▒░
        $adapterDictSignal = Resolve-PathFromDictionary -Dictionary $Conductor -Path "Adapters" | Select-Object -Last 1
        $jacketListSignal     = Resolve-PathFromDictionary -Dictionary $Conductor -Path "AdapterJackets" | Select-Object -Last 1

        $opSignal.MergeSignal(@($adapterDictSignal, $jacketListSignal))

        if ($adapterDictSignal.Failure()) {
            Add-PathToDictionary -Dictionary $Conductor -Path "Adapters" -Value @{} | Out-Null
            $opSignal.LogRecovery("Initialized missing AdapterDictionary on Conductor.")
        }

        if ($jacketListSignal.Failure()) {
            $opSignal.LogCritical("AdapterJackets  not found on the conductor.")
            return $opSignal
        }

        $jacketList = $jacketListSignal.GetResult()

        # ░▒▓█ ATTACHMENT JACKET RESOLUTION █▓▒░
        foreach ($jacket in $jacketList) {
            if ($null -ne $jacket) {

                $nameSignal = Resolve-PathFromDictionary -Dictionary $jacket -Path "Name" | Select-Object -Last 1

                if ($opSignal.MergeSignalAndVerifySuccess($nameSignal)) {
                    $name = $nameSignal.GetResult()
                
                    $resolveSignal = Resolve-AdapterFromJacket -Signal $Signal -ConductionContext $Conductor -Jacket $jacket | Select-Object -Last 1
                
                    if ($opSignal.MergeSignalAndVerifySuccess($resolveSignal)) {
                        $resolvedAdapter = $resolveSignal.GetResult()
                        $resolvedType = $resolvedAdapter.GetType().Name
                        $opSignal.LogVerbose("Adapter '$name' resolved as type '$resolvedType'.")
                
                        $addSignal = Register-AdapterToMappedSlot -Conductor $Conductor -Adapter $resolveSignal | Select-Object -Last 1
                
                        if ($opSignal.MergeSignalAndVerifySuccess($addSignal)) {
                            $opSignal.LogInformation("Adapter '$name' mounted successfully.")
                        } else {
                            $opSignal.LogWarning("Failed to mount '$name' into Conductor memory.")
                        }
                    } else {
                        $opSignal.LogWarning("Adapter '$name' failed resolution.")
                    }
                } else {
                    $opSignal.LogWarning("Skipped jacket — 'Name' field unresolved.")
                }
                
            } else {
                $opSignal.LogWarning("Null jacket encountered during iteration — skipping.")
            }
        }

        $opSignal.LogInformation("All conductor adapters processed.")
    }
    catch {
        $opSignal.LogCritical("Unhandled critical failure in Resolve-ConductorAdapters: $($_.Exception.Message)")
    }

    return $opSignal
}
