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

    [Signal]Invoke([string]$Slot, [string]$Activity, [Signal]$ConductionSignal, [object]$Plan, [Signal]$ItemSignal) {

        # For the Content Condenser, the plan contains the steps to perform, similar to the steps in the FormulaGraphCondenser but 2 dimensional mappings

        $opSignal = [Signal]::Start("MemoryCondenser.Invoke", $ItemSignal) | Select-Object -Last 1
        
        # First Supported Activities -> Select, Merge, Project
        $DefaultPath = "%.@"
        if ($Activity) {
            switch ($Activity) {

                # Converts a named object Array into a graph, or takes a graph and extends it with an array.  (Move to Graph Condenser and join with GridCondenser functionality like navigate grid?)
                "Persist" {
                    break
                }

                "Generate" {
                    ###n/a# $Plan May be the container with the source details or it may be in a mappings collection

                    $mappings = $null    

                    $mappingsSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "Mappings" -SignalLevel "Information" | Select-Object -Last 1
                    if ($mappingsSignal.HasResult()) {
                        $mappings = @($mappingsSignal.GetResult())
                    }

                    # TODO: Change to the DependsOn model like phases use
                    $resultSignal = $null
                    $_ItemSignal = [Signal]::Start("MemoryCondenser.MappingSignal") | Select-Object -Last 1
                    $ItemSignal.CreateGraph()
                    foreach ($mapping in @($mappings)) {

                        $descriptionSignal = Resolve-PathFromDictionary -Dictionary $mapping -Path "Description" -SignalLevel "Information" | Select-Object -Last 1
                        if ($descriptionSignal.HasResult())
                        {
                            $opSignal.LogInformation($descriptionSignal.GetResult(), @("Verbose"))
                        }

                        $IsEnabledSignal = Resolve-PathFromDictionary -Dictionary $mapping -Path "IsEnabled" -Default $true | Select-Object -Last 1
                        if ($opSignal.MergeSignalAndVerifyFailure($IsEnabledSignal)) { return $opSignal }
                        if (-not $IsEnabledSignal.GetResult()) {
                            continue
                        }


                        # Load the environment from Content storage and merge with passed in Environment *.#.Adapters
                        $PathSignal = Resolve-PathFromDictionary -Dictionary $mapping -Path "Path" -SignalLevel "Warning" | Select-Object -Last 1
                        $ResourceSignal = Resolve-PathFromDictionary -Dictionary $mapping -Path "Resource" -SignalLevel "Warning" | Select-Object -Last 1
                        $ContainerSignal = Resolve-PathFromDictionary -Dictionary $mapping -Path "Container" -SignalLevel "Warning" | Select-Object -Last 1
                        $FormatSignal = Resolve-PathFromDictionary -Dictionary $mapping -Path "Format" -SignalLevel "Warning" | Select-Object -Last 1
                        $ModeSignal = Resolve-PathFromDictionary -Dictionary $mapping -Path "Mode" -Default "Select" -SignalLevel "Warning" | Select-Object -Last 1
                        $ActivitySignal = Resolve-PathFromDictionary -Dictionary $mapping -Path "Activity" -SignalLevel "Warning" | Select-Object -Last 1
                        $TypeSignal = Resolve-PathFromDictionary -Dictionary $mapping -Path "Type" -Default "Transform" | Select-Object -Last 1
                        $HydrationPlanSignal = Resolve-PathFromDictionary -Dictionary $mapping -Path "HydrationPlan" -Default $null | Select-Object -Last 1
                        $KeySignal = Resolve-PathFromDictionary -Dictionary $mapping -Path "Key" -Default $null | Select-Object -Last 1
                        $ExitAfterAdapterSignal = Resolve-PathFromDictionary -Dictionary $mapping -Path "ExitAfterAdapter" -Default $false | Select-Object -Last 1

                        $Key = $KeySignal.HasResult() ? $KeySignal.GetResult() : $null
                        $MappingResultSignal = $null

                        $Path = $PathSignal.HasResult()     ? $PathSignal.GetResult()     : $null
                        $Format = $FormatSignal.HasResult()    ? $FormatSignal.GetResult()    : $null
    
                        $AdapterSignal = Resolve-PathFromDictionary -Dictionary $mapping -Path "Adapter" -SignalLevel "Warning"  | Select-Object -Last 1
                        if ($AdapterSignal.HasResult()) {
                            #                            $Container = $ContainerSignal.HasResult() ? $ContainerSignal.GetResult() : $null
                            #                           $Resource = $ResourceSignal.HasResult() ? $ResourceSignal.GetResult() : $null

                            $MappingResultSignal = Invoke-MappedAdapter `
                                -Signal $ConductionSignal `
                                -Adapter $AdapterSignal.GetResult() `
                                -Activity $ActivitySignal.GetResult() `
                                -Plan $mapping `
                                -ItemSignal $ItemSignal #`
                            #-Name $Resource
                            #                                -Container $Container `
                            | Select-Object -Last 1

                            if ($opSignal.MergeSignalAndVerifyFailure($MappingResultSignal)) { return $opSignal }
                            $this.RegisterSignal($ItemSignal, $Key, $MappingResultSignal)
                        }

                        if ($MappingResultSignal -and -not $ExitAfterAdapterSignal.GetResult()) {

                            # Apply Hydration Steps

                            # Perform Document formatting, xml, json or leave txt
                            if ($Format) {
                                $FormatSignal = [Signal]::Start("MemoryCondenser.Invoke.Format", $ItemSignal) | Select-Object -Last 1
                                $FormatSignal.SetJacket($MappingResultSignal)
                                $FormatSignal.SetPointer($ItemSignal.GetPointer())

                                $MappingResultSignal = Invoke-CondenserAdapter -Slot "Format" -Activity $Format -Plan $mapping -Signal $ConductionSignal -ItemSignal $FormatSignal | Select-Object -Last 1
                                if ($opSignal.MergeSignalAndVerifyFailure($MappingResultSignal)) { return $opSignal }
                                $this.RegisterSignal($ItemSignal, $Key, $MappingResultSignal)
                            }

                            # Optional Condenser-Based Transform Step
                            # Currently uses a CondenserAdapter and then uses the SourceType in the mapping to determine which one to use and SourceMode to determine which activity to run.
                            if ($Path) {
                                $TransformSignal = [Signal]::Start("MemoryCondenser.Invoke.Format", $ItemSignal) | Select-Object -Last 1
                                $TransformSignal.SetJacket($MappingResultSignal)
                                $TransformSignal.SetPointer($ItemSignal.GetPointer())

                                $MappingResultSignal = Invoke-CondenserAdapter -Slot $TypeSignal.GetResult() -Activity $ModeSignal.GetResult() -Plan $mapping -Signal $ConductionSignal -ItemSignal $TransformSignal | Select-Object -Last 1
                                if ($opSignal.MergeSignalAndVerifyFailure($MappingResultSignal)) { return $opSignal }
                                $this.RegisterSignal($ItemSignal, $Key, $MappingResultSignal)
                            }
                
                            # Optional Hydration Condenser Step
                            if ($HydrationPlanSignal.HasResult()) {
                                $HydrationSignal= [Signal]::Start("MemoryCondenser.Invoke.Format", $ItemSignal) | Select-Object -Last 1
                                $HydrationSignal.SetJacket($MappingResultSignal)
                                $HydrationSignal.SetPointer($ItemSignal.GetPointer())

                                $HydrationPlan = [PSCustomObject]@{
                                        Path = "%.@"
                                        HydrationPlan = $HydrationPlanSignal.GetResult()
                                    }

                                # Perform Hydration
                                $MappingResultSignal = Invoke-CondenserAdapter -Slot "Hydration" -Plan $HydrationPlan -Signal $ConductionSignal -ItemSignal $HydrationSignal | Select-Object -Last 1
                                if ($opSignal.MergeSignalAndVerifyFailure($MappingResultSignal)) { return $opSignal }
                                $this.RegisterSignal($ItemSignal, $Key, $MappingResultSignal)
                            }
                            <#
                            # Optional Target Step, uses the TargetAdapter to determine which adapter and slot to use then the activity is passed through.
                            $TargetAdapterSignal = Resolve-PathFromDictionary -Dictionary $mapping -Path "TargetAdapter" -SignalLevel "Information" | Select-Object -Last 1
                            $TargetActivitySignal = Resolve-PathFromDictionary -Dictionary $mapping -Path "TargetActivity" -SignalLevel "Information" | Select-Object -Last 1

                            if ($TargetAdapterSignal.HasResult()) {
                                $ItemSignal.SetJacket($MappingResultSignal)

                                $MappingResultSignal = Invoke-MappedAdapter `
                                    -Signal $ConductionSignal `
                                    -Adapter $TargetAdapterSignal.GetResult() `
                                    -Activity $TargetActivitySignal.GetResult() `
                                    -Plan $mapping `
                                -ItemSignal $ItemSignal
                                | Select-Object -Last 1

                                $this.RegisterSignal($ItemSignal, $Key, $MappingResultSignal)
                            }
                            #>
                        }
                    }
                    break
                }

                default {
                    $opSignal.LogWarning("Unsupported Activity: $Activity")
                    break
                }
            }
        }
        
        $returnItemSignalSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "ReturnItemSignal" -Default $false | Select-Object -Last 1
        if ($returnItemSignalSignal.GetResult())
        {
            $opSignal.SetResult($ItemSignal)
        }

        return $opSignal
    }

    [Signal] RegisterSignal(
        [Signal]$itemSignal,
        [string]$Key,
        [Signal]$registerSignal) {
        if ($null -ne $Key -and $Key -ne "") {
            $itemSignal.Pointer.RegisterSignal($Key, $registerSignal)
        }

        return $itemSignal
    }
}
