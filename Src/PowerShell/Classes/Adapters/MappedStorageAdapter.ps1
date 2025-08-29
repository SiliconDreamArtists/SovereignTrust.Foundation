class MappedStorageAdapter {
    [Signal]$Signal

    MappedStorageAdapter() {
        # Use static Start() instead
    }

    static [Signal] Start([object]$Conductor) {
        $opSignal = [Signal]::Start("MappedStorageAdapter.Start") | Select-Object -Last 1

        if (-not $Conductor) {
            $opSignal.LogCritical("❌ Null Conductor passed to MappedStorageAdapter.Start()")
            return $opSignal
        }

        try {
            $adapter = [MappedStorageAdapter]::new()
            $adapter.Signal = [Signal]::Start("MappedStorageAdapter") | Select-Object -Last 1
            $adapter.Signal.SetJacket($Conductor)
            $adapter.Signal.SetReversePointer($Conductor)

            $graphSignal = [Graph]::Start("MappedStorageAdapter", $adapter, $false)
            $adapter.Signal.SetResult($graphSignal.GetResult())
            $adapter.Signal.SetPointer($graphSignal.GetResult())

            $opSignal.SetResult($adapter)
            $opSignal.LogInformation("✅ MappedStorageAdapter initialized.")
        }
        catch {
            $opSignal.LogCritical("💥 Exception in MappedStorageAdapter.Start(): $_")
        }

        return $opSignal
    }

    [Signal] RegisterAdapter([object]$AdapterInstance, [string]$Key = "StorageService") {
        $opSignal = [Signal]::Start("RegisterMappedAdapter:$Key") | Select-Object -Last 1
        if ($AdapterInstance -isnot [Signal]) {
            $adapterSignal = [Signal]::Start("Adapter:$Key") | Select-Object -Last 1
            $adapterSignal.SetResult($AdapterInstance)
        }
        else {
            $adapterSignal = $AdapterInstance
        }

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

    [Signal] Invoke([string]$Slot, [string]$Path) {
        $opSignal = [Signal]::Start("MappedStorageAdapter.Invoke:$Slot.$Path") | Select-Object -Last 1

        $conductor = $this.Signal.GetJacket()
        return Invoke-StorageAdapter -MappedAdapterSignal $this.Signal -Conduit $null -Conductor $this.Signal.GetJacket() -Path $Path -Slot $Slot | Select-Object -Last 1

        return $opSignal
    }

    [Signal] InvokeAdapterMethod([string]$MethodName, [object[]]$Args) {
        $opSignal = [Signal]::Start("MappedStorageAdapter.Invoke:$MethodName") | Select-Object -Last 1
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

<#
================================================================================
📦 MappedStorageAdapter • AI Trainer Block (Doctrine v1.0)
================================================================================

MappedStorageAdapter is the sovereign abstraction layer for accessing
memory-bearing storage services. It is responsible for routing all storage
requests — such as loading JSON, XML, text, deleting files, or listing folders —
through a signal-aware fallback mechanism across all registered services.

This abstraction obeys the SovereignTrust Doctrine:

🧠 Memory is Sovereign.
Storage is not assumed. Each request resolves through the memory space 
of attached services, each carrying its own jacket, slot, and lineage.

📡 Signals are Living.
All operations return Signals — traceable, mergeable, and idempotent.
Failures are not silent. All fallback is logged and lineage-aware.

🔁 Adapters are Evolving.
Each registered service is a dynamic adapter. Services can be replaced,
mutated, or upgraded without altering the conduction flow above.

♾️ Recursion is Home.
This object can defer to its owning Conductor. The Conductor can fall back
to its HostConductor. Together, they form the recursive memory fabric that
bootstraps Sovereign execution.

MappedStorageAdapter enables runtime access to all sovereign plans,
templates, modules, and data — using only memory and WirePath.

> “When memory becomes sovereign, storage becomes signal.”

#>
