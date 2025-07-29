# =============================================================================
# 🧠 SovereignTrust Diagnostic Utility: Test-IsClassDefined
# =============================================================================
# Checks whether a PowerShell class is defined or resolvable from the current
# application domain. Returns a Signal with embedded result and diagnostics.
#
# ✅ Use this in dynamic loading, plugin detection, or conditional execution
# 📦 Supports namespace-style resolution from assemblies and runtime classes
# =============================================================================

function Test-IsClassDefined {
    param (
        [Parameter(Mandatory)]
        [string]$ClassName
    )

    $opSignal = [Signal]::Start("Test-IsClassDefined:$ClassName") | Select-Object -Last 1

    try {
        # ░▒▓█ TYPE DIRECT QUERY █▓▒░
        $type = [Type]::GetType($ClassName, $false)
        if ($type) {
            $opSignal.LogVerbose("✅ Class found via [Type]::GetType(): $ClassName")
            $opSignal.SetResult($true)
            return $opSignal
        }

        # ░▒▓█ ASSEMBLY SCAN █▓▒░
        $opSignal.LogVerbose("🔍 Scanning assemblies for class: $ClassName")
        $type = [AppDomain]::CurrentDomain.GetAssemblies() |
            ForEach-Object { $_.GetType($ClassName, $false) } |
            Where-Object { $_ -ne $null } |
            Select-Object -First 1

        if ($type) {
            $opSignal.LogVerbose("✅ Class found in assembly: $($type.Assembly.FullName)")
            $opSignal.SetResult($true)
        }
        else {
            $opSignal.LogWarning("❌ Class not found: $ClassName")
            $opSignal.SetResult($false)
        }
    }
    catch {
        $opSignal.LogCritical("🔥 Error while checking class: $($_.Exception.Message)")
        $opSignal.SetResult($false)
    }

    return $opSignal
}
