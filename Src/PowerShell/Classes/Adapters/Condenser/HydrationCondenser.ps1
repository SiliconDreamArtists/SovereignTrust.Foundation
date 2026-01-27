# =============================================================================
# 💧 HydrationCondenser (Context Import + Token Resolver)
#  License: MIT License • Copyright (c) 2025 Silicon Dream Artists / BDDB
#  Authors: Shadow PhanTom ☠️🧁👾️/🤖 • Neural Alchemist ⚗️☣️🐲 • Last Updated: 05/20/2025
# =============================================================================
# Condenser for resolving tokens, importing graph memory, and applying contextual
# substitutions from external XML-based token maps. Used in dynamic hydration
# flows during SDA Fusion execution and Conduction plan generation.
# =============================================================================

class HydrationCondenser {
    [Conductor]$Conductor
    [MappedCondenserAdapter]$MappedCondenserAdapter
    [Signal]$Signal  # Formerly ControlSignal

    HydrationCondenser() {
        # Empty constructor — use Start() method instead.
    }

    static [HydrationCondenser] Start([MappedCondenserAdapter]$mappedAdapter, [Conductor]$conductor) {
        $instance = [HydrationCondenser]::new()
        $instance.MappedCondenserAdapter = $mappedAdapter
        $instance.Conductor = $conductor
        $instance.Signal = [Signal]::Start("HydrationCondenser.Control") | Select-Object -Last 1
        return $instance
    }

    [Signal]Invoke($Slot, $Activity, $Signal, $Plan, $ItemSignal) {
        $opSignal = [Signal]::Start("HydrationCondenser.Invoke", $ItemSignal) | Select-Object -Last 1

        # TODO: Review, do we want to clone $ItemSignal since hydration modifies in place?
        $resultSignal = Invoke-ApplyHydrationCondenser -Signal $Signal -Plan $Plan -ItemSignal $ItemSignal 
        $opSignal.SetResult($resultSignal.GetResult())
        return $opSignal
    }

    [Signal] GetToken([string]$Value, $CondenserSignal, [bool]$ThrowExceptionOnEmpty = $true, [int]$RetryAttempts = 2) {
        $opSignal = [Signal]::Start("GetToken:$Value") | Select-Object -Last 1

        if ([string]::IsNullOrWhiteSpace($Value)) {
            $opSignal.LogWarning("Token value was empty or null.")
            return $opSignal
        }

        $firstLookup = $Value.IndexOf(".")
        if ($firstLookup -lt 0) {
            $opSignal.LogWarning("Token missing required lookup structure (no dot separator): $Value")
            return $opSignal
        }

        $tokenGraphFilePath = $Value.Substring(0, $firstLookup)
        $xpath = "/" + $Value.Substring($firstLookup).Replace(".", "/").Replace("[", "[@").Replace("[@@", "[@")

        $matchingNavigators = $CondenserSignal.Context.FindMatchingContextDictionary($tokenGraphFilePath)
        $opSignal.MergeSignal($matchingNavigators)

        $navigators = $matchingNavigators.GetResult()
        if (-not $navigators -or $navigators.Count -eq 0) {
            $opSignal.LogCritical("Token graph dictionary not found for: $Value")
            return $opSignal
        }

        foreach ($navigator in $navigators) {
            try {
                $node = $navigator.SelectSingleNode($xpath)
                if ($node) {
                    $opSignal.SetResult($node.InnerXml)
                    $opSignal.LogInformation("Token resolved: $Value → $($node.InnerXml)")
                    return $opSignal
                }
            }
            catch {
                $opSignal.LogWarning("Navigator exception for path '$xpath': $_")
            }
        }

        $opSignal.LogCritical("Token not resolved — node not found at: $xpath")
        return $opSignal
    }

    [Signal] GetContext($TokenDocument, $TokenGraphOverrides, $OverloadGraphVirtualPath = $null) {
        $opSignal = [Signal]::Start("GetContext") | Select-Object -Last 1

        try {
            $settings = $this.GetMergeCondenserSettings()
            $nodeName = $settings.CondenserSettingsNodeName

            $tokenGraphsSignal = if ($TokenDocument -is [Newtonsoft.Json.Linq.JToken]) {
                [Signal]::Start($TokenDocument.SelectToken($nodeName)) | Select-Object -Last 1
            }
            else {
                Resolve-PathFromDictionary -Dictionary $TokenDocument -Path $nodeName
            }

            $opSignal.MergeSignal($tokenGraphsSignal)
            $tokenGraphs = $tokenGraphsSignal.GetResult()
            if (-not $tokenGraphs) {
                $opSignal.LogWarning("Tokens node '$nodeName' not found in TokenDocument.")
                return $opSignal
            }

            $graphsNode = $tokenGraphs[$settings.TokensNodeName][$settings.GraphNodeName]
            if (-not $graphsNode) {
                $opSignal.LogWarning("Graph node '$($settings.GraphNodeName)' not found under Tokens.")
                return $opSignal
            }

            $tokenGraphRoot = $graphsNode[$settings.TokenGraphRootNodeName]
            $importListRaw = $graphsNode[$settings.ImportNodeName]
            if (-not $tokenGraphRoot -or -not $importListRaw) {
                $opSignal.LogWarning("Missing tokenGraphRoot or importList.")
                return $opSignal
            }

            $context = @{}

            $replacements = $graphsNode["replacements"]
            if ($replacements) {
                $context.Replacements += (ConvertFrom-Json (ConvertTo-Json $replacements))
            }

            $importList = @(ConvertFrom-Json (ConvertTo-Json $importListRaw))

            if ($TokenGraphOverrides) {
                $overrideImports = $TokenGraphOverrides[$settings.ImportNodeName]
                if ($overrideImports) {
                    $importList += @(ConvertFrom-Json (ConvertTo-Json $overrideImports))
                }

                $overrideReplacements = $TokenGraphOverrides["replacements"]
                if ($overrideReplacements) {
                    $context.Replacements += (ConvertFrom-Json (ConvertTo-Json $overrideReplacements))
                }
            }

            foreach ($tokenGraph in ($importList | Invoke-SortDictionary -Unique)) {
                $relativePath = $tokenGraph.Replace("\", "/")
                $adjustedBasePath = $tokenGraphRoot

                if ($relativePath.Contains("/")) {
                    $splitParts = $relativePath.Split("/")
                    $relativePath = $splitParts[-1]
                    $adjustedBasePath = Join-Path -Path $tokenGraphRoot -ChildPath ($tokenGraph.Replace($relativePath, ""))
                }

                $graphSignal = $this.Conductor.MappedStorageService.ReadXmlXpath(
                    $relativePath, $null, $adjustedBasePath, $null, "Documents"
                )

                if ($opSignal.MergeSignalAndVerifySuccess($graphSignal)) {
                    $context.ContextNavigator[$relativePath] = $graphSignal.GetResult().CreateNavigator()
                }
                else {
                    $opSignal.LogCritical("Aborted graph loading: $relativePath")
                    return $opSignal
                }
            }

            $opSignal.SetResult($context)
            $opSignal.LogInformation("✅ Token context environment built.")
        }
        catch {
            $opSignal.LogCritical("Unhandled exception in GetContext: $($_.Exception.Message)")
        }

        return $opSignal
    }
}
