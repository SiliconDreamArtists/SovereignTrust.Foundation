# =============================================================================
# 🧠 Invoke-PathHydration
#  Delegated logic for Hot Path, Hydration, and Memory Resolution
#  License: MIT License • Copyright (c) 2025 Silicon Dream Artists / BDDB
#  Authors: Shadow PhanTom 🤖/☠️🏋️😾️ • Neural Alchemist ⚗️☣️🐲 • Version: 2025.5.4.8
# =============================================================================

function Invoke-PathHydration {
    param (
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][Signal]$Signal
    )

    $opSignal = [Signal]::Start("Invoke-PathHydration", $Signal) | Select-Object -Last 1

    $reserved = @("Signal", "Result", "Pointer", "Grid", "Jacket")
    $containsSymbols = $Path -match '[$@%*#]'
    $containsReserved = $reserved | Where-Object { $Path -match "\b$_\b" }

    if ($containsSymbols -or $containsReserved) {
        $opSignal.LogVerbose("🤖 Skipping hydration: already contains symbolic markers.")
        $opSignal.SetResult($Path)
        return $opSignal
    }

    $hydrationSignal = Resolve-PathHydration -CompactPath $Path | Select-Object -Last 1
    $opSignal.MergeSignal($hydrationSignal) | Out-Null

    if ($hydrationSignal.Success()) {
        $opSignal.SetResult($hydrationSignal.GetResult())
        $opSignal.LogInformation("🧬 Hydrated compact path to: $($hydrationSignal.GetResult())")
    } else {
        $opSignal.LogCritical("❌ Path hydration failed.")
    }

    return $opSignal
}