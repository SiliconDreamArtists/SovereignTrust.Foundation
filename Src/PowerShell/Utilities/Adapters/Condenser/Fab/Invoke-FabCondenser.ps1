function Invoke-FabCondenser {
    [CmdletBinding()]
    param (
        [Signal]$Signal,
        [Conductor]$Conductor
    )

    $opSignal = [Signal]::Start("Invoke-FabCondenser", $Signal) | Select-Object -Last 1

    $jacket = $Signal.GetJacket()

    if ($null -ne $jacket) {
        $nameSignal = Resolve-PathFromDictionary -Dictionary $jacket -Path "Name" | Select-Object -Last 1

        if ($opSignal.MergeSignalAndVerifySuccess($nameSignal)) {
            $name = $nameSignal.GetResult()

            $resolveSignal = Resolve-AdapterFromJacket -Signal $Signal -ConductionContext $Conductor -Jacket $jacket | Select-Object -Last 1

            if ($opSignal.MergeSignalAndVerifySuccess($resolveSignal)) {
                $resolvedAdapter = $resolveSignal.GetResult()
                $resolvedType = $resolvedAdapter.GetType().Name
                $opSignal.LogVerbose("Adapter '$name' resolved as type '$resolvedType'.")

                $addSignal = Register-AdapterToMappedSlot-NonGrid -Conductor $Conductor -Adapter $resolveSignal | Select-Object -Last 1

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

    return $opSignal
}
