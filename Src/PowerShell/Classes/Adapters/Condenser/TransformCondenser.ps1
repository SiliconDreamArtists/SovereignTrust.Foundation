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
                "Select" {
                    $sourceSignal = Resolve-PathFromDictionary -Dictionary $ItemSignal -Path $DefaultPath | Select-Object -Last 1

                    $sourcePathSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "Path" | Select-Object -Last 1
                    $sourceFormatSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "Format" -Default ""  | Select-Object -Last 1
                    $SourceHtmlDecodeSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "HtmlDecode" -Default $true | Select-Object -Last 1

                    if ($opSignal.MergeSignalAndVerifyFailure($sourceSignal) -or $opSignal.MergeSignalAndVerifyFailure($sourcePathSignal) -or $opSignal.MergeSignalAndVerifyFailure($sourceFormatSignal) -or $opSignal.MergeSignalAndVerifyFailure($SourceHtmlDecodeSignal)) {
                        $opSignal.LogCritical("❌ Failed to resolve content for Transform")
                        return $opSignal
                    }

                    $source = $sourceSignal.GetResult()

                    # Invoke-FormatJson should receive the JSON text (or object) directly, not via -Path unless it truly expects a file path
                    $resultSignal = Invoke-TransformSelect -Source $source -SourcePath $sourcePathSignal.GetResult() -SourceFormat $sourceFormatSignal.GetResult() -SourceHtmlDecode $SourceHtmlDecodeSignal.GetResult() | Select-Object -Last 1
                    if ($opSignal.MergeSignalAndVerifyFailure($resultSignal)) {
                        $opSignal.LogCritical("❌ JSON formatting failed.")
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
                        $opSignal.LogCritical("❌ Failed to resolve content for Transform")
                        return $opSignal
                    }

                    $source = $sourceSignal.GetResult($true)

                    # Invoke-FormatJson should receive the JSON text (or object) directly, not via -Path unless it truly expects a file path
                    $resultSignal = Invoke-TransformInject -Target $source -Source $source -Path $pathSignal.GetResult() -Format $formatSignal.GetResult() -HtmlEncode $htmlEncodeSignal.GetResult() | Select-Object -Last 1
                    if ($opSignal.MergeSignalAndVerifyFailure($resultSignal)) {
                        $opSignal.LogCritical("❌ JSON formatting failed.")
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
                        $opSignal.LogCritical("❌ Failed to resolve content for Transform")
                        return $opSignal
                    }

                    $MergeResultSignal = Invoke-MergeJson -Base $BaseSignal.GetResult() -Overlay $OverlaySignal.GetResult() -MergeArrayHandling $MergeArrayHandlingSignal.GetResult() -MergeNullValueHandling $MergeNullValueHandlingSignal.GetResult() -Depth $DepthSignal.GetResult() | Select-Object -Last 1
                    if ($opSignal.MergeSignalAndVerifySuccess($MergeResultSignal)) {
                        $opSignal.SetResult($MergeResultSignal.GetResult())
                    }
                    break
                }

                default {
                    $opSignal.LogWarning("⚠️ Unsupported Activity: $Activity")
                    break
                }
            }
        }

        return $opSignal
    }


    [Signal] InvokeByParameter([object]$Base, [object]$Overlay, [bool]$IgnoreInternalObjects = $true) {
        $opSignal = [Signal]::Start("TransformCondenser.Invoke-ByParameter") | Select-Object -Last 1

        $mergeSignal = Invoke-TransformCondenserUnifiedMemory -Base $Base -Overlay $Overlay | Select-Object -Last 1

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
