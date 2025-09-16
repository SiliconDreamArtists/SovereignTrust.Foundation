#Export-ModuleMember -Function *
Export-ModuleMember -Function Invoke-ConvertToUnifiedHashtable
Export-ModuleMember -Function Invoke-MergeCondenserDictionaries
Export-ModuleMember -Function Invoke-MergeCondenserUnifiedMemory


# ================================
# 📦 MergeCondenser.ps1 
# ================================
#
# This module provides sovereign memory merge utilities for use inside
# SDA's SovereignTrust Conduction layer. All merges return Signal-wrapped
# results, support graph/signal unification, and respect memory lineage.
#
# Core Functions:
#   - Invoke-MergeCondenserDictionaries
#   - Invoke-ConvertToUnifiedHashtable
#   - Invoke-MergeCondenserUnifiedMemory
#   - MergeCondenser (class)
#
# Doctrine Status:
#   ✅ Sovereign Memory
#   ✅ Living Signals
#   ✅ Adapter Evolution
#   ✅ Temporal Recursion
#


function Invoke-ConvertToUnifiedHashtable {
    param (
        [Parameter(Mandatory)][object]$InputObject
    )

    $signal = [Signal]::Start("Invoke-ConvertToUnifiedHashtable") | Select-Object -Last 1

    try {
        if ($InputObject -is [Signal]) {
            $InputObject = $InputObject.GetResult()
        }

        $converted = $null

        if ($InputObject -is [Graph]) {
            $converted = $InputObject._Memory3
        }
        elseif ($InputObject -is [ordered]) {
            $converted = $InputObject
        }
        elseif ($InputObject -is [hashtable]) {
            $converted = [ordered]@{} + $InputObject
        }
        else {
            try {
                $ht = @{}
                $InputObject.PSObject.Properties | ForEach-Object {
                    $ht[$_.Name] = $_.Value
                }
                $converted = [ordered]@{} + $ht
            } catch {
                throw "❌ Could not convert $($InputObject.GetType().Name) to ordered hashtable: $_"
            }
        }

        $signal.SetResult($converted)
        $signal.LogInformation("✅ Object normalized to ordered hashtable.")
    }
    catch {
        $signal.LogCritical("❌ Failed to convert object to ordered hashtable: $($_.Exception.Message)")
    }

    return $signal
}

function Invoke-MergeCondenserDictionaries {
    param (
        [Parameter(Mandatory)][hashtable]$Base,
        [Parameter(Mandatory)][hashtable]$Overlay,
        [Parameter()][bool]$Recursive = $true
    )

    $signal = [Signal]::Start("Invoke-MergeCondenserDictionaries") | Select-Object -Last 1

    function Merge-Inner {
        param (
            [hashtable]$target,
            [hashtable]$source
        )

        foreach ($key in $source.Keys) {
            if ($target.ContainsKey($key)) {
                if ($Recursive -and $target[$key] -is [hashtable] -and $source[$key] -is [hashtable]) {
                    Merge-Inner -target $target[$key] -source $source[$key]
                } else {
                    $target[$key] = $source[$key]
                }
            } else {
                $target[$key] = $source[$key]
            }
        }
    }

    try {
        Merge-Inner -target $Base -source $Overlay
        $signal.SetResult($Base)
        $signal.LogInformation("✅ Hashtable merge completed successfully.")
    } catch {
        $signal.LogCritical("🔥 Exception in Invoke-MergeCondenserDictionaries: $($_.Exception.Message)")
    }

    return $signal
}

function Invoke-MergeCondenserUnifiedMemory {
    param (
        [Parameter(Mandatory)][object]$Base,
        [Parameter(Mandatory)][object]$Overlay
    )

    $signal = [Signal]::Start("Invoke-MergeCondenserUnifiedMemory") | Select-Object -Last 1

    try {
        $baseHash   = Invoke-ConvertToUnifiedHashtable -InputObject $Base | Select-Object -Last 1
        $overlayHash = Invoke-ConvertToUnifiedHashtable -InputObject $Overlay | Select-Object -Last 1

        $mergeSignal = Invoke-MergeCondenserDictionaries -Base $baseHash.GetResult() -Overlay $overlayHash.GetResult() | Select-Object -Last 1
        $signal.MergeSignal($mergeSignal)

        if ($mergeSignal.Success()) {
            $signal.SetResult($mergeSignal.GetResult())
            $signal.LogInformation("✅ Merge completed successfully using unified memory.")
        } else {
            $signal.LogWarning("⚠️ Merge failed in unified memory flow.")
        }
    } catch {
        $signal.LogCritical("🔥 Exception during unified memory merge: $($_.Exception.Message)")
    }

    return $signal
}
