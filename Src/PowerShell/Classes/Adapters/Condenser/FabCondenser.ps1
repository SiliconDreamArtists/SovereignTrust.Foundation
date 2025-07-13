# =============================================================================
# 🧩 FabCondenser (Symbolic Mapping + Contextual Replacement)
#  License: MIT License • Copyright (c) 2025 Silicon Dream Artists / BDDB
#  Authors: Shadow PhanTom ☠️🧁👾️/🤖 • Neural Alchemist ⚗️☣️🐲 • Last Updated: 07/12/2025
# =============================================================================
# Performs template condensation using dynamic mappings and embedded context.
# Resolves tags such as `@@TAG`, `##TAG`, `<TAG />` using sovereign source maps.
# Often used in Condenser chains during token hydration, agent bootstrap, or
# reactive publishing from flattened proposal schemas.
# =============================================================================

class FabCondenser {
    [Conductor]$Conductor
    [MappedCondenserAdapter]$MappedCondenserAdapter
    [Signal]$Signal  # Previously ControlSignal

    FabCondenser() {
        # Empty constructor — use .Start()
    }
       
    static [FabCondenser] Start([MappedCondenserAdapter]$mappedAdapter, [Conductor]$conductor) {
        $instance = [FabCondenser]::new()
        $instance.MappedCondenserAdapter = $mappedAdapter
        $instance.Conductor = $conductor
        $instance.Signal = [Signal]::Start("FabCondenser.Control") | Select-Object -Last 1
        return $instance
    }

    [Signal] Invoke([Signal]$Signal, [object]$Proposal, [object]$Context = $null) {
        $opSignal = [Signal]::Start("FabCondenser.Invoke", $Signal) | Select-Object -Last 1

        if ($null -eq $Proposal) {
            $ProposalSignal = Resolve-PathFromDictionary -Dictionary $Signal -Path "%.Proposal" | Select-Object -Last 1
            $Proposal = $ProposalSignal.GetResult()
        }

        if ($null -eq $Context) {
            $ContextSignal = Resolve-PathFromDictionary -Dictionary $Signal -Path "%.Context" | Select-Object -Last 1
            $Context = $ContextSignal.GetResult()
        }

        $resultSignal = Invoke-FabCondenser -Signal $Signal -Proposal $Proposal -Context $Context | Select-Object -Last 1
        $opSignal.MergeSignal($resultSignal)

        if ($resultSignal.HasResult()) {
            $opSignal.SetResult($resultSignal.GetResult())
        }

        return $opSignal
    }
}
