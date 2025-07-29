$TokenDispatch = @{
    '*' = 'Invoke-GlobalCondenser'
    '@' = 'Invoke-TokenCondenser'
    '+' = 'Invoke-JsonCondenser'
    '-' = 'Invoke-StringCondenser'
    '~' = 'Invoke-NavigatorCondenser'
    '#' = 'Invoke-MapCondenser'
    '$' = 'Invoke-MergeCondenser'
}

function Invoke-HydrationCondenser {
    param (
        [Parameter(Mandatory)] [Signal]$Signal,
        [Parameter(Mandatory)] [object]$Plan,
        [Parameter(Mandatory)] [object]$ItemSignal
    )

    $opSignal = [Signal]::Start("HydrationCondenser", $Signal) | Select-Object -Last 1

    # Assume there are no changes until a change occurs.
    $opSignal.SetResult($false)

    try {
        $hydrationPlanSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "HydrationPlan" | Select-Object -Last 1
        if (-not $opSignal.MergeSignalAndVerifySuccess(@($hydrationPlanSignal))) {
            $opSignal.LogInformation("ℹ️ No HydrationPlan specified, skipping hydration.")
            return $Signal
        }

        $hydrationPlan = $hydrationPlanSignal.GetResult()
    
        foreach ($step in ($hydrationPlan.ToCharArray())) {
            switch ($step) {
                '^' {
                    $oldResult = $Signal.GetResult() | ConvertTo-Json -Depth 99
                    do {
                        $prev = $oldResult
                        $stepSignal = Invoke-HydrationCondenser -Signal $Signal -Plan $Plan -ItemSignal $ItemSignal | Select-Object -Last 1
                        $oldResult = $stepSignal.GetResult() | ConvertTo-Json -Depth 99
                    } while ($prev -ne $oldResult)
                    $stepSignal
                }
                default {
                    if ($TokenDispatch.ContainsKey([string]$step)) {
                        $stepSignal = & $TokenDispatch[[string]$step] -Signal $Signal -Plan $Plan -ItemSignal $ItemSignal | Select-Object -Last 1
                    } else {
                        $opSignal.LogWarning("⚠️ Unknown hydration step: $step")
                        continue
                    }
                }
            }

            if (-not $opSignal.MergeSignalAndVerifySuccess(@($stepSignal))) {
                $opSignal.LogCritical("❌ Hydration step '$step' failed.")
                break
            }

            if ($stepSignal.HasResult()) {
                $opSignal.SetResult($stepSignal.GetResult())
            }
        }
    }
    catch {
        $opSignal.LogCritical("🔥 HydrationCondenser exception: $_")
    }

    return $opSignal
}
