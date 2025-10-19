# =============================================================================
# 🔄 TransformCondenser (Declarative Memory Overlay & Unification Engine)
#  License: MIT License • Copyright (c) 2025 Silicon Dream Artists / BDDB
#  Authors: Shadow PhanTom ☠️🧁👾️/🤖 • Neural Alchemist ⚗️☣️🐲 • Last Updated: 05/20/2025
# =============================================================================
# Performs recursive, additive overlay merging between structured sovereign memory types.
#
# This is used to perform conversions, similar to Format
#
# Check Doctrine Alignment:
# • Sovereign Memory: ✅
# • Living Signals: ✅
# • Adapter Evolution: ✅
# • Temporal Recursion: ✅
# =============================================================================

class TransformCondenser {
    [Conductor]$Conductor
    [MappedCondenserAdapter]$MappedCondenserAdapter
    [Signal]$Signal  # Sovereign control signal (previously ControlSignal)

    TransformCondenser() {
    }

    static [TransformCondenser] Start([MappedCondenserAdapter]$mappedAdapter, [Conductor]$conductor) {
        $instance = [TransformCondenser]::new()
        $instance.MappedCondenserAdapter = $mappedAdapter
        $instance.Conductor = $conductor
        $instance.Signal = [Signal]::Start("TransformCondenser.Control") | Select-Object -Last 1
        return $instance
    }


    [Signal] InvokeByParameter([object]$Base, [object]$Overlay, [bool]$IgnoreInternalObjects = $true) {
        $opSignal = [Signal]::Start("TransformCondenser.Invoke-ByParameter") | Select-Object -Last 1

        $mergeSignal = Invoke-MergeCondenserUnifiedMemory -Base $Base -Overlay $Overlay | Select-Object -Last 1

        if ($opSignal.MergeSignalAndVerifySuccess($mergeSignal)) {
            $opSignal.SetResult($mergeSignal.GetResult())
            $opSignal.LogInformation("✅ Merge completed successfully via unified invocation.")
        }
        else {
            $opSignal.LogWarning("⚠️ Merge operation failed in Invoke-ByParameter.")
        }

        $this.Signal.MergeSignal($opSignal)
        return $opSignal
    }
}
