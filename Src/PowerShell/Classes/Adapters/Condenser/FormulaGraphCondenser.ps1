class FormulaGraphCondenser {
    [Conductor]$Conductor
    [MappedCondenserAdapter]$MappedCondenserAdapter
    [Signal]$Signal  # Sovereign control signal

    FormulaGraphCondenser() {
        # Empty constructor, to enforce use of .Start()472
    }

    static [FormulaGraphCondenser] Start([MappedCondenserAdapter]$mappedAdapter, [Conductor]$conductor) {
        $instance = [FormulaGraphCondenser]::new()
        $instance.MappedCondenserAdapter = $mappedAdapter
        $instance.Conductor = $conductor
        $instance.Signal = [Signal]::Start("FormulaGraphCondenser")
        return $instance
    }

    [Signal] Invoke() {
        $opSignal = [Signal]::Start("FormulaGraphLauncher.Invoke", $this.Signal) | Select-Object -Last 1

        $sourceSignal = Resolve-PathFromDictionary -Dictionary $this.Conductor -Path "%.FlatFormulaSource" | Select-Object -Last 1
        $opSignal.MergeSignal($sourceSignal) | Out-Null

        if ($opSignal.MergeSignalAndVerifyFailure($sourceSignal)) {
            $opSignal.LogCritical("❌ Failed to resolve FlatFormulaSource.")
            return $opSignal
        }

        $sourceData = $sourceSignal.GetResult()

        # Construct signal to feed into the FormulaGraphCondenser
        $feedSignal = [Signal]::Start("FormulaGraphCondenser.Feed", $opSignal, $null, $sourceData) | Select-Object -Last 1
        Add-PathToDictionary -Dictionary $feedSignal -Path "$.%.GraphPlans" -Value $sourceData.GraphPlans | Out-Null

        # Call our declarative plan processor
        $resultSignal = Invoke-FormulaGraphCondenser -ConductionSignal $feedSignal | Select-Object -Last 1
        $opSignal.MergeSignal($resultSignal) | Out-Null

        $opSignal.SetResult($resultSignal.GetResult())
        return $opSignal
    }

    [Signal] InvokeFromPlanPath([string]$PlanWirePath, [object]$jacketObject) {
        $opSignal = [Signal]::Start("FormulaGraphCondenser.InvokeFromPlanPath") | Select-Object -Last 1

        # Determine base memory to evolve (from existing Result or jacket)
        $initialMemory = if ($this.Signal -and $this.Signal.HasResult()) {
            $this.Signal.GetResult()
        }
        else {
            $jacketObject
        }

        # Start a new signal for Condenser with memory + jacket
        $condenserSignal = [Signal]::Start("GraphCondenser", $jacketObject) | Select-Object -Last 1
        $condenserSignal.SetJacket($jacketObject) | Out-Null

        # Extract graph plans using WirePath
        $planSignal = Resolve-PathFromDictionary -Dictionary $condenserSignal -Path $PlanWirePath | Select-Object -Last 1
        if ($opSignal.MergeSignalAndVerifyFailure($planSignal)) {
            $opSignal.LogCritical("❌ Failed to resolve GraphPlans from path: $PlanWirePath")
            return $opSignal
        }

        # Inject plans into %.GraphPlans for downstream Condenser
        $graphPlans = $planSignal.GetResult()
        Add-PathToDictionary -Dictionary $condenserSignal -Path "%.%.%.@.GraphPlans" -Value $graphPlans | Out-Null

        # 🔁 Invoke the FormulaGraphCondenser
        $resultSignal = Invoke-FormulaGraphCondenser -Signal $condenserSignal | Select-Object -Last 1

        # Merge final state back to opSignal for continuity
        $opSignal.SetResult($resultSignal.GetResult())
        $opSignal.MergeSignal($resultSignal)

        return $opSignal
    }

    [Signal] InvokeFromPlanPathOld([string]$PlanWirePath, [object]$jacketObject) {
        $opSignal = [Signal]::Start("FormulaGraphCondenser.InvokeFromPlanPath") | Select-Object -Last 1

        # Construct base signal with your jacketed runtime object
        $condenserSignal = [Signal]::Start("GraphCondenser", $opSignal, $null, $jacketObject) | Select-Object -Last 1
        $condenserSignal.SetJacket($jacketObject) | Out-Null

        # Extract the graph plan array from the wire path
        $planSignal = Resolve-PathFromDictionary -Dictionary $condenserSignal -Path $PlanWirePath | Select-Object -Last 1
        if ($opSignal.MergeSignalAndVerifyFailure($planSignal)) {
            $opSignal.LogCritical("❌ Failed to resolve GraphPlans from path: $PlanWirePath")
            return $opSignal
        }

        # Attach plans into expected %.GraphPlans
        $graphPlans = $planSignal.GetResult()
        Add-PathToDictionary -Dictionary $condenserSignal -Path "$.%.GraphPlans" -Value $graphPlans | Out-Null

        # 🔁 Run the plan-driven processor
        $resultSignal = Invoke-FormulaGraphCondenser -Signal $condenserSignal | Select-Object -Last 1
        $opSignal.MergeSignal($resultSignal)

        return $opSignal
    }

}
