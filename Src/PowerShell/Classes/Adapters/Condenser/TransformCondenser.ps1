# =============================================================================
# 🔄 TransformCondenser (
#       Select: Performs a select from a text based format
#       Project: Performs across an axis in order to create a recordset from another recordset using a default content set. (Can this be done by the MergeCondenser?))
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

    [Signal]Invoke([string]$Slot, [string]$Activity, [Signal]$ConductionSignal, [object]$Plan, [Signal]$ItemSignal) {
        $opSignal = [Signal]::Start("TransformCondenser.Invoke") | Select-Object -Last 1

        # First Supported Activities -> Select, Merge, Project
        $DefaultPath = "%.@"
        if ($Activity) {
            switch ($Activity) {

                # Select using a path from an xml or json object.
                "Project" {
                    # This should generally be done after a mapping has pushed an adapter call into the Grid memory of the ItemSignal, attempt to use the Plan's Key to look for them.
                    $KeySignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "Key" -SignalLevel "Warning" | Select-Object -Last 1
                    $result = @()

                    if ($KeySignal.HasResult())
                    {
                        $SourceTransformNodesSignal = Resolve-PathFromDictionary -Dictionary $ItemSignal -Path "*.#.$($KeySignal.GetResult())" | Select-Object -Last 1
                        if ($SourceTransformNodesSignal.HasResult())
                        {
                            $ContentPlan = [PSCustomObject]@{
                                Path = $Plan.Path
#                                HydrationPlan = "@"
                            }

                            $SourceContentResultSignal = Invoke-MappedAdapter -Adapter "Token.Memory"  -Activity "Get" -Plan $ContentPlan -ItemSignal $ItemSignal -Signal $ConductionSignal | Select-Object -Last 1
                            if ($SourceContentResultSignal.HasResult())
                            {
                                $null = Add-PathToDictionary -Dictionary $ContentPlan -Path "HydrationPlan" -Value "@"
                                $content = $SourceContentResultSignal.GetResult()                             
                                $nodes = @($SourceTransformNodesSignal.GetResult().GetResult())

                                foreach ($node in $nodes)
                                {
                                    $HydrationPlan = [PSCustomObject]@{
                                        Path = "%.@"
                                        HydrationPlan = "@"
                                    }

                                    #$null = Add-PathToDictionary -Dictionary $ContentPlan -Path "Config" -Value $node
                                    $HydrationSignal = [Signal]::Start("TransformCondenser.Invoke.Hydration") | Select-Object -Last 1
                                    $SourceContentResultSignal.SetResult($content)
                                    $HydrationSignal.SetJacket($SourceContentResultSignal)
                                    $HydrationSignal.SetPointer($ItemSignal.GetPointer())
                                    $HydrationSignal.SetResult($node)
                                    
                                    # Perform Hydration
                                    $MappingResultSignal = Invoke-CondenserAdapter -Slot "Hydration" -Plan $HydrationPlan -Signal $ConductionSignal -ItemSignal $HydrationSignal | Select-Object -Last 1
                                    #$this.RegisterSignal($ItemSignal, $Key, $MappingResultSignal)
                                    $signResult = "a"

                                    
                                    $result += $MappingResultSignal.GetResult()
                                }
                            }
                            
                        }
                    }

                    $opSignal.SetResult($result)
                    break
                }

                # Select using a path from an xml or json object.
                "Select" {
                    $sourceSignal = Resolve-PathFromDictionary -Dictionary $ItemSignal -Path $DefaultPath | Select-Object -Last 1

                    $sourcePathSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "Path" | Select-Object -Last 1
                    $sourceFormatSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "Format" -Default ""  | Select-Object -Last 1
                    $SourceHtmlDecodeSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "HtmlDecode" -Default $true | Select-Object -Last 1

                    if ($opSignal.MergeSignalAndVerifyFailure($sourceSignal) -or $opSignal.MergeSignalAndVerifyFailure($sourcePathSignal) -or $opSignal.MergeSignalAndVerifyFailure($sourceFormatSignal) -or $opSignal.MergeSignalAndVerifyFailure($SourceHtmlDecodeSignal)) {
                        $opSignal.LogCritical("Failed to resolve content for Transform")
                        return $opSignal
                    }

                    $source = $sourceSignal.GetResult()

                    # Invoke-FormatJson should receive the JSON text (or object) directly, not via -Path unless it truly expects a file path
                    $resultSignal = Invoke-TransformSelect -Source $source -SourcePath $sourcePathSignal.GetResult() -SourceFormat $sourceFormatSignal.GetResult() -SourceHtmlDecode $SourceHtmlDecodeSignal.GetResult() | Select-Object -Last 1
                    if ($opSignal.MergeSignalAndVerifyFailure($resultSignal)) {
                        $opSignal.LogCritical("JSON formatting failed.")
                        return $opSignal
                    }

                    $opSignal.SetResult($resultSignal.GetResult())
                    break
                }

                # Injects using a path to an xml or json object.
                "Inject" {

                    # HASN'T BEEN IMPLEMENTED, WILL CALL FUNCTION Invoke-TransformInject
                    $sourceSignal = Resolve-PathFromDictionary -Dictionary $ItemSignal -Path $DefaultPath | Select-Object -Last 1

                    $pathSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "TargetPath" | Select-Object -Last 1
                    $formatSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "TargetFormat" | Select-Object -Last 1
                    $htmlEncodeSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "TargetHtmlEncode" -Default $false | Select-Object -Last 1

                    if ($opSignal.MergeSignalAndVerifyFailure($sourceSignal) -or $opSignal.MergeSignalAndVerifyFailure($pathSignal) -or $opSignal.MergeSignalAndVerifyFailure($formatSignal) -or $opSignal.MergeSignalAndVerifyFailure($htmlEncodeSignal)) {
                        $opSignal.LogCritical("Failed to resolve content for Transform")
                        return $opSignal
                    }

                    $source = $sourceSignal.GetResult($true)

                    # Invoke-FormatJson should receive the JSON text (or object) directly, not via -Path unless it truly expects a file path
                    $resultSignal = Invoke-TransformInject -Target $source -Source $source -Path $pathSignal.GetResult() -Format $formatSignal.GetResult() -HtmlEncode $htmlEncodeSignal.GetResult() | Select-Object -Last 1
                    if ($opSignal.MergeSignalAndVerifyFailure($resultSignal)) {
                        $opSignal.LogCritical("JSON formatting failed.")
                        return $opSignal
                    }

                    $opSignal.SetResult($resultSignal.GetResult())
                    break
                }

                # Merges Json objects or builds an array
                "Merge" {

                    $BaseSignal = Resolve-PathFromDictionary -Dictionary $ItemSignal -Path "$DefaultPath.Base" | Select-Object -Last 1
                    $OverlaySignal = Resolve-PathFromDictionary -Dictionary $ItemSignal -Path "$DefaultPath.Overlay" | Select-Object -Last 1
                    $MergeArrayHandlingSignal = Resolve-PathFromDictionary -Dictionary $ItemSignal -Path "$DefaultPath.MergeArrayHandling" -Default "Merge" | Select-Object -Last 1
                    $MergeNullValueHandlingSignal = Resolve-PathFromDictionary -Dictionary $ItemSignal -Path "$DefaultPath.MergeNullValueHandling" -Default "Ignore" | Select-Object -Last 1
                    $DepthSignal = Resolve-PathFromDictionary -Dictionary $ItemSignal -Path "$DefaultPath.Depth" -Default 100 | Select-Object -Last 1

                    if ($opSignal.MergeSignalAndVerifyFailure($BaseSignal) -or $opSignal.MergeSignalAndVerifyFailure($OverlaySignal)) {
                        $opSignal.LogCritical("Failed to resolve content for Transform")
                        return $opSignal
                    }

                    $MergeResultSignal = Invoke-MergeJson -Base $BaseSignal.GetResult() -Overlay $OverlaySignal.GetResult() -MergeArrayHandling $MergeArrayHandlingSignal.GetResult() -MergeNullValueHandling $MergeNullValueHandlingSignal.GetResult() -Depth $DepthSignal.GetResult() | Select-Object -Last 1
                    if ($opSignal.MergeSignalAndVerifySuccess($MergeResultSignal)) {
                        $opSignal.SetResult($MergeResultSignal.GetResult())
                    }
                    break
                }

                default {
                    $opSignal.LogWarning("Unsupported Activity: $Activity")
                    break
                }
            }
        }

        return $opSignal
    }
}
