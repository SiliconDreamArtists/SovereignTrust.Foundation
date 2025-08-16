# =============================================================================
# 🧠 SDA MemoryCondenser
#  SovereignTrust Memory Interface for performing Invoke-MemoryCondenser calls
#  License: MIT License • Copyright (c) 2025 Silicon Dream Artists / BDDB
#  Authors: Shadow PhanTom 🤖/☠️🧁👾️ • Neural Alchemist ⚗️☣️🐲 • Version: 2025.5.4.8
# =============================================================================

class MemoryCondenser {
    [Signal]$Signal

    MemoryCondenser() {}

    static [Signal] Start([MappedCondenserAdapter]$adapter, [Conductor]$conductor) {
        $opSignal = [Signal]::Start("MemoryCondenser.Start") | Select-Object -Last 1

        $instance = [MemoryCondenser]::new()
        $instance.Signal = [Signal]::Start("MemoryCondenser", $adapter) | Select-Object -Last 1
        $instance.Signal.SetJacket($conductor) | Out-Null

        $opSignal.SetResult($instance)
        $opSignal.LogInformation("✅ MemoryCondenser initialized.")
        return $opSignal
    }

    [Signal] InvokeByParameter(
        [string]$Action,
        [string]$Path,
        [object]$Value,
        [object]$TargetMemory,
        [hashtable]$HydrationPlan,
        [string]$HotPathMapPath = "%.HotPaths"
    ) {
        $opSignal = [Signal]::Start("MemoryCondenser.InvokeByParameter", $this.Signal) | Select-Object -Last 1

        # 🔍 Step 1: Hot Path Resolution
        $hotPathSignal = Invoke-HotPathResolution -Path $Path -Signal $this.Signal -HotPathMapPath $HotPathMapPath | Select-Object -Last 1
        if ($opSignal.MergeSignalAndVerifyFailure($hotPathSignal)) {
            $opSignal.LogCritical("❌ Hot path resolution failed.")
            return $opSignal
        }

        $resolvedHotPath = $hotPathSignal.GetResult()

        # 💧 Step 2: Path Hydration
        $hydratedSignal = Invoke-PathHydration -Path $resolvedHotPath -Signal $this.Signal -SignalFirst:$true | Select-Object -Last 1
        if ($opSignal.MergeSignalAndVerifyFailure($hydratedSignal)) {
            $opSignal.LogCritical("❌ Path hydration failed.")
            return $opSignal
        }

        $finalPath = $hydratedSignal.GetResult()

        # 🧠 Step 3: Memory I/O Delegation
        $memorySignal = Invoke-MemoryCondenser -Action $Action -Path $finalPath -Value $Value -HostSignal $this.Signal -TargetMemory $TargetMemory -HydrationPlan @{ Skip = $true } | Select-Object -Last 1
        $opSignal.MergeSignal($memorySignal)

        return $opSignal
    }
}
