function Invoke-FabCondenser {
    [CmdletBinding()]
    param (
        [Signal]$Signal,
        [Conductor]$Conductor
    )

    $opSignal = [Signal]::Start("Invoke-FabCondenser", $Signal) | Select-Object -Last 1

    $jacket = $Signal.GetJacket()

    if ($null -ne $jacket) {
        $nameSignal = Resolve-PathFromDictionary -Dictionary $jacket -Path "@.Name" | Select-Object -Last 1

        if ($opSignal.MergeSignalAndVerifySuccess($nameSignal)) {
            $name = $nameSignal.GetResult()

            $jacketSignal = $jacket

            $settingsSignal = Resolve-PathFromDictionary -Dictionary $jacket -Path "@.Settings" -FailureLogLevel "Warning" | Select-Object -Last 1
            if ($settingsSignal.Success() -and $settingsSignal.HasResult())
            {

                $adaptersSignal = Resolve-PathFromDictionary -Dictionary $settingsSignal -Path "@.Adapters" | Select-Object -Last 1
                if ($adaptersSignal.Success()) {
                    $adapters = $adaptersSignal.GetResult()
                    $adapterCount = $adapters.Count
                    $opSignal.LogVerbose("Jacket '$name' contains $adapterCount adapters.")


                    foreach ($adapter in $adapters) {
                        $adapterSignal = [Signal]::Start("Invoke-FabCondenser", $Signal) | Select-Object -Last 1
                        $adapterSignal.SetResult($adapter) | Out-Null

                        $conductorSignal = [Signal]::Start("Invoke-FabCondenser", $Signal) | Select-Object -Last 1
                        $conductorSignal.SetResult($Conductor) | Out-Null
                        
                        $adapterSignal.SetJacket($conductorSignal) | Out-Null
                        $adapterJacketSignal = [Signal]::Start("Invoke-FabCondenser", $adapterSignal) | Select-Object -Last 1
                        $adapterJacketSignal.SetJacket($adapterSignal) | Out-Null
                        
                        $invokeFabCondenserSignal = Invoke-FabCondenser -Signal $adapterJacketSignal -Conductor $Conductor | Select-Object -Last 1
                        $opSignal.MergeSignal($invokeFabCondenserSignal)
                    }

                }
                else {
                    $opSignal.LogVerbose("Jacket '$name' contains no adapters.")
                }
            }
            else {

                $conductorSignal = [Signal]::Start("Invoke-FabCondenser", $Signal) | Select-Object -Last 1
                $conductorSignal.SetJacket($Conductor.Signal) | Out-Null

                $resolveSignal = Resolve-AdapterFromJacket -Signal $conductorSignal -ConductionContext $conductorSignal -Jacket $jacketSignal | Select-Object -Last 1

                if ($opSignal.MergeSignalAndVerifySuccess($resolveSignal)) {
                    $resolvedAdapter = $resolveSignal.GetResult()
                    $resolvedType = $resolvedAdapter.GetType().Name
                    $opSignal.LogVerbose("Adapter '$name' resolved as type '$resolvedType'.")

                    $addSignal = Register-AdapterToMappedSlot -ConductorJacketSignal $Conductor.Signal -Adapter $resolveSignal.GetResult() | Select-Object -Last 1

                    #$addSignal = Register-AdapterToMappedSlot -Conductor $Conductor -Adapter $resolveSignal | Select-Object -Last 1

                    if ($opSignal.MergeSignalAndVerifySuccess($addSignal)) {
                        $opSignal.LogInformation("Adapter '$name' mounted successfully.")
                    }
                    else {
                        $opSignal.LogWarning("Failed to mount '$name' into Conductor memory.")
                    }
                }
                else {
                    $opSignal.LogWarning("Adapter '$name' failed resolution.")
                }
            }
        }
    }
    else {
        $opSignal.LogWarning("Null jacket encountered during iteration — skipping.")
    }

    return $opSignal
}

Write-Host "Invoke-FabCondenser loaded." -ForegroundColor Green