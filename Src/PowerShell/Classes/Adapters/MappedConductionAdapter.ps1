class MappedConductionAdapter {
    [Signal]$Signal

    MappedConductionAdapter() {
        # Use static Start() instead
    }

    static [Signal] Start([object]$Conductor) {
        $opSignal = [Signal]::Start("MappedConductionAdapter.Start") | Select-Object -Last 1

        if (-not $Conductor) {
            $opSignal.LogCritical("❌ Null Conductor passed to MappedConductionAdapter.Start()")
            return $opSignal
        }

        try {
            $adapter = [MappedConductionAdapter]::new()
            $adapter.Signal = [Signal]::Start("MappedConductionAdapter") | Select-Object -Last 1
            $adapter.Signal.SetJacket($Conductor)
            $adapter.Signal.SetReversePointer($Conductor)

            $graphSignal = [Graph]::Start("MappedConductionAdapter", $adapter, $false)
            $adapter.Signal.SetPointer($graphSignal.GetResult())

            $opSignal.SetResult($adapter)
            $opSignal.LogInformation("✅ MappedConductionAdapter initialized.")
        }
        catch {
            $opSignal.LogCritical("💥 Exception in MappedConductionAdapter.Start(): $_")
        }

        return $opSignal
    }

    [Signal] RegisterAdapter([object]$AdapterInstance, [string]$Key = "ConductionService") {
        $opSignal = [Signal]::Start("RegisterMappedAdapter:$Key") | Select-Object -Last 1
        if ($AdapterInstance -isnot [Signal]) {
            $adapterSignal = [Signal]::Start("Adapter:$Key") | Select-Object -Last 1
            $adapterSignal.SetResult($AdapterInstance)
        }
        else {
            $adapterSignal = $AdapterInstance
        }

        $AddMappedAdapterSignal = Add-PathToDictionary -Dictionary $AdapterInstance -Path "MappedAdapter" -Value $this | Select-Object -Last 1
        $graph = $this.Signal.GetPointer()
        $registerSignal = $graph.RegisterSignal($Key, $adapterSignal)
        $opSignal.MergeSignal($registerSignal)

        if ($registerSignal.Success()) {
            $opSignal.LogInformation("✅ Registered adapter at key: '$Key'")
        } else {
            $opSignal.LogWarning("⚠️ Failed to register adapter at key: '$Key'")
        }

        $this.Signal.MergeSignal($opSignal)
        return $opSignal
    }

    [Signal] Invoke([string]$Slot, [object]$Context, [object]$Plan) {
        $opSignal = [Signal]::Start("MappedConductionAdapter.Invoke:$Slot") | Select-Object -Last 1

        $conductor = $this.Signal.GetJacket()
        $opSignal = Invoke-ConductionAdapter -MappedAdapterSignal $this.Signal -Conduit $null -Conductor $this.Signal.GetJacket() -ConductionSignal $Context -Slot $Slot | Select-Object -Last 1

        return $opSignal
    }

    [Signal] InvokeAdapterMethod([string]$MethodName, [object[]]$Args) {
        $opSignal = [Signal]::Start("MappedConductionAdapter.Invoke:$MethodName") | Select-Object -Last 1
        $graph = $this.Signal.GetPointer()

        foreach ($key in $graph.Grid.Keys) {
            $adapterSignal = $graph.Grid[$key]
            $adapter = $adapterSignal.GetResult()

            if ($null -ne $adapter -and ($adapter | Get-Member -Name $MethodName)) {
                $result = $adapter.InvokeMethod($MethodName, $Args)
                $opSignal.MergeSignal($result)

                if ($result.Success()) {
                    $opSignal.SetResult($result.GetResult())
                    $opSignal.LogInformation("🎯 Adapter '$key' successfully invoked '$MethodName'")
                    break
                } else {
                    $opSignal.LogWarning("⚠️ Adapter '$key' failed on method '$MethodName'")
                }
            } else {
                $opSignal.LogVerbose("⏭️ Adapter '$key' does not implement '$MethodName'")
            }
        }

        if (-not $opSignal.Success()) {
            $opSignal.LogCritical("❌ No adapter succeeded for method '$MethodName'")
        }

        $this.Signal.MergeSignal($opSignal)
        return $opSignal
    }
}
