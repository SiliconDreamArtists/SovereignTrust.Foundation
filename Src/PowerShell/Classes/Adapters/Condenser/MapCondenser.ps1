# =============================================================================
# 🧩 MapCondenser (Symbolic Mapping + Contextual Replacement)
#  License: MIT License • Copyright (c) 2025 Silicon Dream Artists / BDDB
#  Authors: Shadow PhanTom ☠️🧁👾️/🤖 • Neural Alchemist ⚗️☣️🐲 • Last Updated: 07/12/2025
# =============================================================================
# Performs template condensation using dynamic mappings and embedded context.
# Resolves tags such as `@@TAG`, `##TAG`, `<TAG />` using sovereign source maps.
# Often used in Condenser chains during token hydration, agent bootstrap, or
# reactive publishing from flattened Plan schemas.
# =============================================================================

class MapCondenser {
    [Conductor]$Conductor
    [MappedCondenserAdapter]$MappedCondenserAdapter
    [Signal]$Signal  # Previously ControlSignal

    MapCondenser() {
        # Empty constructor — use .Start()
    }
       
    static [MapCondenser] Start([MappedCondenserAdapter]$mappedAdapter, [Conductor]$conductor) {
        $instance = [MapCondenser]::new()
        $instance.MappedCondenserAdapter = $mappedAdapter
        $instance.Conductor = $conductor
        $instance.Signal = [Signal]::Start("MapCondenser.Control") | Select-Object -Last 1
        return $instance
    }

    [Signal] Invoke([Signal]$ItemSignal, [object]$Plan, [object]$Context = $null) {
        $opSignal = [Signal]::Start("MapCondenser.Invoke", $ItemSignal) | Select-Object -Last 1

        if ($null -eq $Plan) {
            $PlanSignal = Resolve-PathFromDictionary -Dictionary $ItemSignal -Path "%.Plan" | Select-Object -Last 1
            $Plan = $PlanSignal.GetResult()
        }

        if ($null -eq $Context) {
            $ContextSignal = Resolve-PathFromDictionary -Dictionary $ItemSignal -Path "%.Context" | Select-Object -Last 1
            $Context = $ContextSignal.GetResult()
        }

        $resultSignal = Invoke-MapCondenser -Signal $ItemSignal -Plan $Plan -Context $Context | Select-Object -Last 1
        $opSignal.MergeSignal($resultSignal)

        if ($resultSignal.HasResult()) {
            $opSignal.SetResult($resultSignal.GetResult())
        }

        return $opSignal
    }
}
