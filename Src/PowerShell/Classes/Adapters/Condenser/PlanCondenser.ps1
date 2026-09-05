# =============================================================================
# 🔐 PlanCondenser (Graph Context + XPath Token Resolution)
#  License: MIT License • Copyright (c) 2025 Silicon Dream Artists / BDDB
#  Authors: Shadow PhanTom ☠️🧁👾️/🤖 • Neural Alchemist ⚗️☣️🐲 • Last Updated: 05/20/2025
# =============================================================================
# Uses XPath-based token lookup with imported graph documents to resolve runtime
# variables within sovereign templates. This condenser class is central to hydration
# flows, token graph processing, and context-sensitive publishing.
# =============================================================================

class PlanCondenser {
    [Conductor]$Conductor
    [MappedCondenserAdapter]$MappedCondenserAdapter
    [Signal]$Signal

    PlanCondenser() {
        # Empty constructor — use Start()
    }

    static [PlanCondenser] Start([MappedCondenserAdapter]$mappedAdapter, [Conductor]$conductor) {
        $instance = [PlanCondenser]::new()
        $instance.MappedCondenserAdapter = $mappedAdapter
        $instance.Conductor = $conductor
        $instance.Signal = [Signal]::Start("PlanCondenser.Control") | Select-Object -Last 1
        return $instance
    }

    [Signal] ResolveInsertPhaseSteps(
        [Signal]$ParentSignal,
        $ConductionSignal,
        $Plan,
        $ItemSignal
    ) {
        $opSignal = [Signal]::Start("PlanCondenser.ResolveInsertPhaseSteps", $ParentSignal) | Select-Object -Last 1

        $iteration = $Plan.Config.Iteration ?? 0
        if ($Plan.Config.PreventReclone -and $iteration -gt 0)
        {
            if ($iteration -gt 1)
            {
                $opSignal.LogInformation("Skip Repeat Cloning")
                return $opSignal
            }
        }

        # Get the steps to inject
        $phaseStepsSignal = Resolve-PathFromDictionary -Dictionary $ItemSignal -Path $Plan.Path | Select-Object -Last 1
        if ($opSignal.MergeSignalAndVerifyFailure($phaseStepsSignal)) { return $opSignal }

        # Get the current phase steps
#        $planStepsSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "Phase.Steps" | Select-Object -Last 1
#        if ($opSignal.MergeSignalAndVerifyFailure($planStepsSignal)) { return $opSignal }

        $phaseSteps = $phaseStepsSignal.GetResult()
#        $planSteps = $planStepsSignal.GetResult()
        $currentPlanName = $Plan.Name

        $breakSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "Config.Break" -Default $false | Select-Object -Last 1
        if ($opSignal.MergeSignalAndVerifyFailure($breakSignal)) { return $opSignal }

        if ($breakSignal.GetResult()) {
            $check = ""
        }

        # Clone steps so they can be reused safely
        $cloneSignal = Resolve-ClonePlan -Plan $phaseSteps | Select-Object -Last 1
        if ($opSignal.MergeSignalAndVerifyFailure($cloneSignal)) { return $opSignal }

        $phaseSteps = $cloneSignal.GetResult()

        $hydrationPlan = [PSCustomObject]@{
            Path          = "%.@"
            HydrationPlan = "@"
            HydrationStyle = "Standard"
            Config        = $Plan.Config
        }

        # Hydrate the injected steps
        $subItemSignal = [Signal]::Start("PlanCondenser.ResolveInsertPhaseSteps", $ItemSignal) | Select-Object -Last 1
        $subItemSignal.SetJacketResult($phaseSteps)

        # Pass through the Pointer so the Hydration process has it available to resolve values.
        $subItemSignal.SetPointer($ItemSignal.GetPointer())

        if ($Plan.Name -like "*ManageLineage"){
            $a = ""
        }

        $stepHydrateResultSignal = Invoke-CondenserAdapter -Slot "Hydration" -Plan $hydrationPlan -Signal $ConductionSignal -ItemSignal $subItemSignal | Select-Object -Last 1
        if ($opSignal.MergeSignalAndVerifyFailure($stepHydrateResultSignal)) { return $opSignal }

        $phaseSteps = $stepHydrateResultSignal.GetResult()

        $skipRenameSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "Config.SkipRename" -Default $false | Select-Object -Last 1
        if (-not $skipRenameSignal.GetResult()) {
            foreach ($step in @($phaseSteps)) {
                $step.Name = "$($currentPlanName)_$($step.Name)"
            }
        }

        <#
        $newSteps = @()
        foreach ($step in @($planSteps)) {
            $newSteps += $step
            if ($step.Name -eq $currentPlanName) {
                $newSteps += $phaseSteps
            }
        }
        #>

        $opSignal.SetResult($phaseSteps)
        return $opSignal
    }

    [Signal] Invoke([string]$Slot, [string]$Activity, $ConductionSignal, $Plan, $ItemSignal) {
        $opSignal = [Signal]::Start("PlanCondenser.Invoke", $ItemSignal) | Select-Object -Last 1

        $PlanPathSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "Path" | Select-Object -Last 1
        $DefaultPath = $PlanPathSignal.GetResult()

        if ($Activity) {
            switch ($Activity) {
                "IteratePhase" {
                    $iterationArraySignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "Config.IterationArray" | Select-Object -Last 1
                    $iterationNameSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "Config.IterationName" -Default "Iteration" | Select-Object -Last 1
                    $iterationArray = $iterationArraySignal.GetResult()

                    foreach ($iteration in $iterationArray) {
                        $iterationPlan = (Resolve-ClonePlan -Plan $Plan | Select-Object -Last 1).GetResult()
                        
                        $iterationPlan.Activity = $Plan.Config.Activity

                        # Put the iteration data in a Signal so it can be put in the ItemSignal Graph for later use.
                        $iterationSignal = [Signal]::Start("Iteration", $ItemSignal) | Select-Object -Last 1
                        $iterationData = [PSCustomObject]@{
                            Value = $iteration
                            IterationArray = $iterationArray
                        }

                        $iterationData = $iteration
                        $iterationSignal.SetResult($iterationData)
                        $ItemSignal.Pointer.RegisterSignal($iterationNameSignal.GetResult(), $iterationSignal)

                        # This shouldn't reply on always calling a condenser.
                        $condenserSlot = ($Plan.Adapter -split '\.')[1]
                        $iterationSignal = Invoke-CondenserAdapter -Slot $condenserSlot -Activity $Plan.Config.Activity -Plan $iterationPlan -Signal $ConductionSignal -ItemSignal $ItemSignal | Select-Object -Last 1
                        if ($opSignal.MergeSignalAndVerifyFailure($iterationSignal)) { return $opSignal }
                    }
                    #TDB
                    break
                }

                "InvokePlan" {
                    #TDB
                   break
                }

                "InvokePhase" {
                     $resolveStepsSignal = $this.ResolveInsertPhaseSteps($opSignal, $ConductionSignal, $Plan, $ItemSignal)
                    if ($opSignal.MergeSignalAndVerifyFailure($resolveStepsSignal) -or (-not $resolveStepsSignal.HasResult())) {
                         return $opSignal 
                    }

                    $phase = [PSCustomObject]@{
                        Steps = @($resolveStepsSignal.GetResult())
                    }

                    $SourceSignal = Invoke-CondenserAdapter -Slot "Memory" -Activity "Generate" -Signal $ConductionSignal -Plan $phase -ItemSignal $ItemSignal | Select-Object -Last 1

                   break
                }

                "InsertPhaseSteps" {
                    $resolveStepsSignal = $this.ResolveInsertPhaseSteps($opSignal, $ConductionSignal, $Plan, $ItemSignal)
                    if ($opSignal.MergeSignalAndVerifyFailure($resolveStepsSignal) -or (-not $resolveStepsSignal.HasResult())) {
                         return $opSignal 
                    }


                    $newSteps = $resolveStepsSignal.GetResult()

                    $phaseStepsSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "Phase.Steps" | Select-Object -Last 1
                    $phaseSteps = @($phaseStepsSignal.GetResult())

                    # Find the index of the current plan object inside Phase.Steps
                    $currentIndex = -1
                    for ($i = 0; $i -lt $phaseSteps.Count; $i++) {
                        if ($phaseSteps[$i].Name -eq $Plan.Name) {
                            $currentIndex = $i
                            break
                        }
                    }

                    if ($currentIndex -ge 0) {
                        $updatedSteps = @()

                        if ($currentIndex -ge 0) {
                            $updatedSteps += $phaseSteps[0..$currentIndex]
                        }

                        $updatedSteps += @($newSteps)

                        if ($currentIndex + 1 -lt $phaseSteps.Count) {
                            $updatedSteps += $phaseSteps[($currentIndex + 1)..($phaseSteps.Count - 1)]
                        }

                        $null = Add-PathToDictionary -Dictionary $Plan -Path "Phase.Steps" -Value $updatedSteps | Select-Object -Last 1
                    }
                    else {
                        $opSignal.LogCritical("Could not find the current plan step inside Phase.Steps.")
                    }

                    break
                }

                "AddPhaseSteps" {
                    $resolveStepsSignal = $this.ResolveInsertPhaseSteps($opSignal, $ConductionSignal, $Plan, $ItemSignal)
                    if ($opSignal.MergeSignalAndVerifyFailure($resolveStepsSignal) -or (-not $resolveStepsSignal.HasResult())) {
                         return $opSignal 
                    }

                    $newSteps = $resolveStepsSignal.GetResult()

                    $null = Add-PathToDictionary -Dictionary $Plan -Path "Phase.Steps" -Value $newSteps | Select-Object -Last 1

                    break
                }

                default {
                    $opSignal.LogCritical("Unsupported Activity: $Activity")
                    break
                }
            }
        }

        return $opSignal
    }
}