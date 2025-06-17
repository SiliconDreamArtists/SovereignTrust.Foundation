# =============================================================================
# 🧩 MapCondenser (Symbolic Mapping + Contextual Replacement)
#  License: MIT License • Copyright (c) 2025 Silicon Dream Artists / BDDB
#  Authors: Shadow PhanTom ☠️🧁👾️/🤖 • Neural Alchemist ⚗️☣️🐲 • Last Updated: 05/20/2025
# =============================================================================
# Performs template condensation using dynamic mappings and embedded context.
# Resolves tags such as `@@TAG`, `##TAG`, `<TAG />` using sovereign source maps.
# Often used in Condenser chains during token hydration, agent bootstrap, or
# reactive publishing from flattened proposal schemas.
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

    [Signal] CondenseTemplate([object]$Proposal, [object]$Context) {
        $opSignal = [Signal]::Start("CondenseTemplate") | Select-Object -Last 1

        if (-not $Proposal -or -not $Proposal.Content) {
            $opSignal.LogCritical("Invalid or missing Proposal.Content for condensation.")
            return $opSignal
        }

        $variableTags = $this.GetVariableTags($Proposal.Content, $Proposal.ReplacementType)

        foreach ($tag in $variableTags) {
            foreach ($source in $Proposal.SourceRelayList) {
                $relayData = $Proposal.RelayData | Where-Object { $_.Key.RelayFilename -eq $source }

                if ($relayData.Value) {
                    $resolved = Resolve-PathFromDictionary -Dictionary $relayData.Value -Path $tag
                    $opSignal.MergeSignal($resolved)

                    if ($resolved.Success()) {
                        $Proposal.Content = $this.ReplaceTagInContent(
                            $Proposal.Content,
                            $resolved.GetResult(),
                            $tag,
                            $Proposal.MappingType,
                            $Proposal.ReplacementType
                        )
                    }
                }
            }
        }

        $opSignal.SetResult(@{ Content = $Proposal.Content })
        $opSignal.LogInformation("Condensation completed.")
        return $opSignal
    }

    [string] ReplaceTagInContent([string]$Input, [string]$Value, [string]$Tag, [string]$MappingType, [string]$ReplacementType) {
        if ($MappingType -eq 'Set') {
            return $Value
        }

        $tags = $this.GetReplacementPatterns($Tag, $ReplacementType)
        foreach ($pattern in $tags) {
            $Input = $Input.Replace($pattern, $Value)
        }

        return $Input
    }

    [string[]] GetReplacementPatterns([string]$Tag, [string]$Type) {
        switch ($Type) {
            'XmlTag'       { return @("<$Tag />", "&lt;$Tag /&gt;") }
            'HashHashtag'  { return @("##$Tag") }
            'AtAttag'      { return @("@@$Tag") }
            default        { return @() }
        }

        return @()
    }

    [string[]] GetVariableTags([string]$Content, [string]$Type) {
        if (-not $Content) { return @() }

        switch ($Type) {
            'AtAttag'     { return [regex]::Matches($Content, "@@[a-zA-Z0-9-]+") | ForEach-Object { $_.Value.Substring(2) } }
            'HashHashtag' { return [regex]::Matches($Content, "##[a-zA-Z0-9_.-]+") | ForEach-Object { $_.Value.Substring(2) } }
            default       { return @() }
        }

        return @()
    }
}
