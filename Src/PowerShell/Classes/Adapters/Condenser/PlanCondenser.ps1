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

    [Signal] Invoke([string]$Slot, [string]$Activity, $ConductionSignal, $Plan, $ItemSignal) {
        $opSignal = [Signal]::Start("PlanCondenser.Invoke", $ItemSignal) | Select-Object -Last 1

        $PlanPathSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "Path" | Select-Object -Last 1
        $DefaultPath = $PlanPathSignal.GetResult()

        if ($Activity) {
            switch ($Activity) {
                "InvokePlan" {
                    #TDB
                    break
                }

                "InsertPhase" {
                    #TDB
                    break
                }

                "InsertPhaseSteps" {
                    # Get The Steps to Inject
                    $phaseStepsSignal = Resolve-PathFromDictionary -Dictionary $ItemSignal -Path $Plan.Path | Select-Object -Last 1
                    if ($opSignal.MergeSignalAndVerifyFailure($phaseStepsSignal)) { return $opSignal}

                    # Inject Steps 
                    $planStepsSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "Phase.Steps" | Select-Object -Last 1
                    if ($opSignal.MergeSignalAndVerifyFailure($planStepsSignal)) { return $opSignal}

                    $phaseSteps = $phaseStepsSignal.GetResult()
                    $planSteps = $planStepsSignal.GetResult()
                    $currentPlanName = $Plan.Name

                    # clone and Iterate through new steps, rename in order to make them unique and re-usable.
                    $phaseSteps = (Resolve-ClonePlan -Plan $phaseSteps | Select-Object -Last 1).GetResult()

                    $HydrationPlan = [PSCustomObject]@{
                        Path           = "%.@"
                        HydrationPlan  = "@"
                        Config = $Plan.Config
                    }

                    # Perform Hydration
                    $subItemSignal = [Signal]::Start("PlanCondenser.Invoke", $ItemSignal) | Select-Object -Last 1
                    $subItemSignal.SetJacketResult($phaseSteps)
                    $StepHydrateResultSignal = Invoke-CondenserAdapter -Slot "Hydration" -Plan $HydrationPlan -Signal $ConductionSignal -ItemSignal $subItemSignal | Select-Object -Last 1
                    if ($opSignal.MergeSignalAndVerifyFailure($StepHydrateResultSignal)) { return $opSignal }

                    $phaseSteps = $StepHydrateResultSignal.GetResult()
                    foreach ($step in @($phaseSteps))
                    {
                        $step.Name = "$($currentPlanName)_$($step.Name)"
                    }
                    
                    $newSteps = @()
                    foreach ($step in @($planSteps))
                    {
                        $newSteps += $step
                        if ($step.Name -eq $currentPlanName){
                            $newSteps += $phaseSteps
                        }
                    }

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
