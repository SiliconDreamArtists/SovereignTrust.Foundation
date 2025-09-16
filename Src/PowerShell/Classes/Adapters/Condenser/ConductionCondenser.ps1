# =============================================================================
# 🚦 ConductionCondenser (SovereignTrust Declarative Command Processor)
#  License: MIT License • Copyright (c) 2025 Silicon Dream Artists / BDDB
#  Authors: Shadow PhanTom 🤖/☠️🌻🚀️ • Neural Alchemist ⚗️☣️🐲 • Last Generated: 05/20/2025
# =============================================================================
# The ConductionCondenser processes declarative ConductionPlans using signal-safe
# execution. Each Phase in the plan resolves a command template and executes it
# in context, emitting traceable signals at each step. This system replaces
# imperative scripts with sovereign lifecycle-encoded execution.

class ConductionCondenser {
    [MappedCondenserAdapter]$MappedCondenserAdapter
    [Conductor]$Conductor
    [Signal]$ControlSignal

    static [ConductionCondenser] Start([MappedCondenserAdapter]$mappedAdapter, [Conductor]$conductor) {
        $instance = [ConductionCondenser]::new()
        $instance.MappedCondenserAdapter = $mappedAdapter
        $instance.Conductor = $conductor
        $instance.ControlSignal = [Signal]::Start("ConductionCondenser") | Select-Object -Last 1
        return $instance
    }

    [Signal] Invoke([object]$Context) {
        return $this.Invoke($Context, $null) | Select-Object -Last 1
    }

    [Signal] Invoke([object]$Context, [object]$Plan) {
        return Invoke-ConductionCondenser -ConductionSignal $Context | Select-Object -Last 1
    }
}
