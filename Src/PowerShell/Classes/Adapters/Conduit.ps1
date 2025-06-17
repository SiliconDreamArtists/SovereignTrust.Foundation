# =============================================================================
# 🔌 MappedConduitAdapter (Sovereign Conduction Routing Adapter)
#  License: MIT License • Copyright (c) 2025 Silicon Dream Artists / BDDB
#  Authors: Shadow PhanTom ☠️🧁👾️/🤖 • Neural Alchemist ⚗️☣️🐲 • Last Generated: 2025-05-22
# =============================================================================
# The MappedConduitAdapter manages dynamic conduit registration and execution
# in the SovereignTrust system. It mirrors the structure of MappedCondenserAdapter,
# enabling signal-based access to invocation routines across multiple conduit types.
#
# Usage:
#  - Conduits are mounted using `RegisterAdapter($Key, $Adapter)` where each
#    adapter is a conduit-compatible runner (e.g., Phase-based, Intent-based).
#  - `InvokeConduitByKey($Key, $Signal)` allows signal-invocation into the adapter.
#
# All adapters must return Signals, preserve sovereign memory, and operate within
# Conduction or Phase doctrine layers.
#
# This adapter provides the execution routing backbone for:
#  → SovereignIntentProcessor
#  → PhaseRouter
#  → ContextualBehaviorConduits
#  → And future AI-aligned execution layers.
#

class MappedConduitAdapter {
    [Signal]$Signal
    [hashtable]$Registry

    MappedConduitAdapter() {
        # Enforce use of .Start()
    }

    static [MappedConduitAdapter] Start() {
        $adapter = [MappedConduitAdapter]::new()
        $adapter.Signal = [Signal]::Start("MappedConduitAdapter") | Select-Object -Last 1
        $adapter.Registry = @{}
        $adapter.Signal.LogInformation("🔌 MappedConduitAdapter initialized.")
        return $adapter
    }

    [Signal] RegisterAdapter([string]$Key, [object]$Adapter) {
        $opSignal = [Signal]::Start("RegisterConduitAdapter:$Key", $this.Signal) | Select-Object -Last 1

        if ($this.Registry.ContainsKey($Key)) {
            $opSignal.LogWarning("⚠️ Overwriting existing conduit adapter with key: $Key")
        }

        $this.Registry[$Key] = $Adapter
        $opSignal.LogInformation("✅ Conduit adapter registered under key: $Key")
        $this.Signal.MergeSignal($opSignal)
        return $opSignal
    }

    [Signal] InvokeConduitByKey([string]$Key, [Signal]$InputSignal) {
        $opSignal = [Signal]::Start("InvokeConduit:$Key", $InputSignal) | Select-Object -Last 1

        if (-not $this.Registry.ContainsKey($Key)) {
            return $opSignal.LogCritical("❌ No conduit adapter registered for key: $Key")
        }

        $adapter = $this.Registry[$Key]

        try {
            if ($adapter -is [System.Management.Automation.ScriptBlock]) {
                $resultSignal = & $adapter.Invoke($InputSignal) | Select-Object -Last 1
            }
            elseif ($adapter -is [object] -and $adapter.PSObject.Properties.Match("Invoke").Count -gt 0) {
                $resultSignal = $adapter.Invoke($InputSignal) | Select-Object -Last 1
            }
            else {
                return $opSignal.LogCritical("❌ Invalid conduit adapter type for key: $Key")
            }

            $opSignal.MergeSignal($resultSignal)
            $opSignal.SetResult($resultSignal.GetResult())
            $opSignal.LogInformation("🧵 Conduit adapter invoked successfully for key: $Key")
        }
        catch {
            $opSignal.LogCritical("🔥 Exception while invoking conduit adapter for key: $Key → $($_.Exception.Message)")
        }

        return $opSignal
    }

    [object] GetAdapter([string]$Key) {
        if ($this.Registry.ContainsKey($Key)) {
            return $this.Registry[$Key]
        }
        return $null
    }

    [string[]] ListKeys() {
        return $this.Registry.Keys
    }
}
