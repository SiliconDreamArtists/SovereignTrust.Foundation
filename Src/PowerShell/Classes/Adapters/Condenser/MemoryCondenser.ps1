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

                    # TODO: Change to the DependsOn model like phases use
                    $resultSignal = $null
                    $_ItemSignal = [Signal]::Start("MemoryCondenser.MappingSignal") | Select-Object -Last 1
                    if (-not $ItemSignal.HasPointer()) {
                        $ItemSignal.CreateGraph()
                    }

                    $step = $this.GetNextStep($null, $Plan)
                    while ($step) {
                        $opSignal.LogInformation("Processing Mapping $($step.Name)", @("Verbose"))
                        $descriptionSignal = Resolve-PathFromDictionary -Dictionary $step -Path "Description" -SignalLevel "Information" | Select-Object -Last 1
                        if ($descriptionSignal.HasResult()) {
                            $opSignal.LogInformation($descriptionSignal.GetResult(), @("Verbose"))
                        }

                        $StepResultSignal = $null

                        # The Deferred Hydration Plan is used to hydrate the step, usually because a previous set puts content in memory or cache.
                        $DeferredHydrationPlanSignal = Resolve-PathFromDictionary -Dictionary $step -Path "DeferredHydrationPlan" -Default $null | Select-Object -Last 1
                        if ($DeferredHydrationPlanSignal.HasResult()) {
                            $HydrationSignal = [Signal]::Start("MemoryCondenser.Invoke.DeferredHydrate", $step) | Select-Object -Last 1
                            $HydrationSignal.SetJacket($StepResultSignal)

                            # Set the Step as the result content of the jacket which is what is going to be hydrated.
                            $HydrationSignal.SetJacketResult($step)
                            $HydrationSignal.SetPointer($ItemSignal.GetPointer())

                            $HydrationPlan = [PSCustomObject]@{
                                Path           = "%.@"
                                HydrationStyle = "Deferred"
                                HydrationPlan  = $DeferredHydrationPlanSignal.GetResult()
                            }

                            # Perform Hydration
                            $StepHydrateResultSignal = Invoke-CondenserAdapter -Slot "Hydration" -Plan $HydrationPlan -Signal $ConductionSignal -ItemSignal $HydrationSignal | Select-Object -Last 1
                            if ($opSignal.MergeSignalAndVerifyFailure($StepHydrateResultSignal)) { return $opSignal }
                            $step = $StepHydrateResultSignal.GetResult()
                        }

                        $null = Add-PathToDictionary -Dictionary $step -Path "Phase" -Value $Plan
                        $IsEnabledSignal = Resolve-PathFromDictionary -Dictionary $step -Path "IsEnabled" -Default $true | Select-Object -Last 1
                        if ($opSignal.MergeSignalAndVerifyFailure($IsEnabledSignal)) { return $opSignal }
                        if ($IsEnabledSignal.GetResult().ToString() -eq "false") {
                            $step = $this.GetNextStep($step, $Plan)
                            continue
                        }

                        # Load the environment from Content storage and merge with passed in Environment *.#.Adapters
                        $PathSignal = Resolve-PathFromDictionary -Dictionary $step -Path "Path" -SignalLevel "Warning" | Select-Object -Last 1
                        $ResourceSignal = Resolve-PathFromDictionary -Dictionary $step -Path "Resource" -SignalLevel "Warning" | Select-Object -Last 1
                        $ContainerSignal = Resolve-PathFromDictionary -Dictionary $step -Path "Container" -SignalLevel "Warning" | Select-Object -Last 1
                        $FormatSignal = Resolve-PathFromDictionary -Dictionary $step -Path "Format" -SignalLevel "Warning" | Select-Object -Last 1
                        $ModeSignal = Resolve-PathFromDictionary -Dictionary $step -Path "Mode" -Default "Select" -SignalLevel "Warning" | Select-Object -Last 1
                        $ActivitySignal = Resolve-PathFromDictionary -Dictionary $step -Path "Activity" -SignalLevel "Warning" | Select-Object -Last 1
                        $TypeSignal = Resolve-PathFromDictionary -Dictionary $step -Path "Type" -Default "Transform" | Select-Object -Last 1
                        $HydrationPlanSignal = Resolve-PathFromDictionary -Dictionary $step -Path "HydrationPlan" -Default $null | Select-Object -Last 1
                        $KeySignal = Resolve-PathFromDictionary -Dictionary $step -Path "Key" -Default $null | Select-Object -Last 1
                        $ExitAfterAdapterSignal = Resolve-PathFromDictionary -Dictionary $step -Path "ExitAfterAdapter" -Default $false | Select-Object -Last 1
                        $ExitAfterAdapterNoResult = Resolve-PathFromDictionary -Dictionary $step -Path "ExitAfterAdapterNoResult" -Default $false | Select-Object -Last 1

                        $Key = $KeySignal.HasResult() ? $KeySignal.GetResult() : $null
                        $Path = $PathSignal.HasResult()     ? $PathSignal.GetResult()     : $null
                        $Format = $FormatSignal.HasResult()    ? $FormatSignal.GetResult()    : $null

                        $AdapterSignal = Resolve-PathFromDictionary -Dictionary $step -Path "Adapter" -SignalLevel "Warning"  | Select-Object -Last 1

                        if ($AdapterSignal.HasResult()) {
                            #                            $Container = $ContainerSignal.HasResult() ? $ContainerSignal.GetResult() : $null
                            #                           $Resource = $ResourceSignal.HasResult() ? $ResourceSignal.GetResult() : $null

                            $StepResultSignal = Invoke-MappedAdapter `
                                -Signal $ConductionSignal `
                                -Adapter $AdapterSignal.GetResult() `
                                -Activity $ActivitySignal.GetResult() `
                                -Plan $step `
                                -ItemSignal $ItemSignal #`
                            #-Name $Resource
                            #                                -Container $Container `
                            | Select-Object -Last 1

                            if ($opSignal.MergeSignalAndVerifyFailure($StepResultSignal)) { return $opSignal }
                            $this.RegisterSignal($ItemSignal, $Key, $StepResultSignal)
                        }

                        if (-not $StepResultSignal.HasResult() -and $ExitAfterAdapterNoResult.GetResult() ) {
                            return $opSignal
                        }

                        if ($StepResultSignal.HasResult() -and (-not $ExitAfterAdapterSignal.GetResult())) {

                            # Apply Hydration Steps

                            # Perform Document formatting, xml, json or leave txt
                            if ($Format) {
                                $FormatSignal = [Signal]::Start("MemoryCondenser.Invoke.Format", $ItemSignal) | Select-Object -Last 1
                                $FormatSignal.SetJacket($StepResultSignal)
                                $FormatSignal.SetPointer($ItemSignal.GetPointer())

                                $StepResultSignal = Invoke-CondenserAdapter -Slot "Format" -Activity $Format -Plan $step -Signal $ConductionSignal -ItemSignal $FormatSignal | Select-Object -Last 1
                                if ($opSignal.MergeSignalAndVerifyFailure($StepResultSignal)) { return $opSignal }
                                $this.RegisterSignal($ItemSignal, $Key, $StepResultSignal)
                            }

                            # Optional Condenser-Based Transform Step
                            # Currently uses a CondenserAdapter and then uses the SourceType in the mapping to determine which one to use and SourceMode to determine which activity to run.
                            if ($Path) {
                                $TransformSignal = [Signal]::Start("MemoryCondenser.Invoke.Transform", $ItemSignal) | Select-Object -Last 1
                                $TransformSignal.SetJacket($StepResultSignal)
                                $TransformSignal.SetPointer($ItemSignal.GetPointer())

                                $StepResultSignal = Invoke-CondenserAdapter -Slot $TypeSignal.GetResult() -Activity $ModeSignal.GetResult() -Plan $step -Signal $ConductionSignal -ItemSignal $TransformSignal | Select-Object -Last 1
                                if ($opSignal.MergeSignalAndVerifyFailure($StepResultSignal)) { return $opSignal }
                                $this.RegisterSignal($ItemSignal, $Key, $StepResultSignal)
                            }
                
                            # Optional Hydration Condenser Step
                            if ($HydrationPlanSignal.HasResult()) {
                                $HydrationSignal = [Signal]::Start("MemoryCondenser.Invoke.Hydrate", $ItemSignal) | Select-Object -Last 1
                                $HydrationSignal.SetJacket($StepResultSignal)
                                $HydrationSignal.SetPointer($ItemSignal.GetPointer())

                                $HydrationPlan = [PSCustomObject]@{
                                    Path          = "%.@"
                                    HydrationPlan = $HydrationPlanSignal.GetResult()
                                }

                                # Perform Hydration
                                $StepResultSignal = Invoke-CondenserAdapter -Slot "Hydration" -Plan $HydrationPlan -Signal $ConductionSignal -ItemSignal $HydrationSignal | Select-Object -Last 1
                                if ($opSignal.MergeSignalAndVerifyFailure($StepResultSignal)) { return $opSignal }
                                $this.RegisterSignal($ItemSignal, $Key, $StepResultSignal)
                            }
                            <#
                            # Optional Target Step, uses the TargetAdapter to determine which adapter and slot to use then the activity is passed through.
                            $TargetAdapterSignal = Resolve-PathFromDictionary -Dictionary $step -Path "TargetAdapter" -SignalLevel "Information" | Select-Object -Last 1
                            $TargetActivitySignal = Resolve-PathFromDictionary -Dictionary $step -Path "TargetActivity" -SignalLevel "Information" | Select-Object -Last 1

                            if ($TargetAdapterSignal.HasResult()) {
                                $ItemSignal.SetJacket($StepResultSignal)

                                $StepResultSignal = Invoke-MappedAdapter `
                                    -Signal $ConductionSignal `
                                    -Adapter $TargetAdapterSignal.GetResult() `
                                    -Activity $TargetActivitySignal.GetResult() `
                                    -Plan $step `
                                -ItemSignal $ItemSignal
                                | Select-Object -Last 1

                                $this.RegisterSignal($ItemSignal, $Key, $StepResultSignal)
                            }
                            #>
                        }

                        $step = $this.GetNextStep($step, $Plan)
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
        if ($returnItemSignalSignal.GetResult()) {
            $opSignal.SetResult($ItemSignal)
        }

        return $opSignal
    }

    [object] GetNextStep(
        [object]$currentStep,
        [object]$phase
    ) {
        $step = $null
        
#        if ($currentStep -and (-not $currentStep.Name))
#        {
#            throw "Steps Must Have Names to be valid."
#        }

 #       $currentStepName = ($currentStep) ? $currentStep.Name : $null
        
        if ($phase.Steps) {
            $phaseSteps = @($phase.Steps)

            # If no current step, return the first step (if any)
            if (-not $currentStep) {
                if ($phaseSteps.Count -gt 0) {
                    return $phaseSteps[0]
                }
                return $null
            }

            # Find current step and return the next one
            for ($i = 0; $i -lt $phaseSteps.Count; $i++) {

                if ($phaseSteps[$i] -eq $currentStep) {

                    $nextIndex = $i + 1
                    if ($nextIndex -lt $phaseSteps.Count) {
                        $step = $phaseSteps[$nextIndex]
                    }

                    break
                }
            }
        }

        return $step
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
