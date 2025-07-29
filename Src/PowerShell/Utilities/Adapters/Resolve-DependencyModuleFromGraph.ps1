function Resolve-DependencyModuleFromGraph {
    param (
        [Parameter(Mandatory = $true)]
        [object]$ConductionContext,

        [Parameter(Mandatory = $true)]
        [string]$WirePath
    )

    $signal = [Signal]::Start("Resolve-DependencyModuleFromGraph:$WirePath") | Select-Object -Last 1

    # ░▒▓█ RESOLVE MODULE SIGNAL █▓▒░
    $pathFormulaSignal = Resolve-ModulePathSignal -WirePath $WirePath | Select-Object -Last 1
    if (-not $signal.MergeSignalAndVerifySuccess($pathFormulaSignal)) {
        $signal.LogCritical("❌ Failed to resolve module signal from wire path: $WirePath")
        return $signal
    }

    # ░▒▓█ GET MODULE JACKET █▓▒░
    $jacketSignal = $pathFormulaSignal.GetResult()
    $manifestSignalWrapper = Resolve-PathFromDictionary -Dictionary $jacketSignal -Path "%" | Select-Object -Last 1
    if (-not $signal.MergeSignalAndVerifySuccess($manifestSignalWrapper)) {
        $signal.LogCritical("❌ Could not retrieve manifest structure from jacket signal.")
        return $signal
    }

    $manifestSignal = $manifestSignalWrapper.GetResult()
    # ░▒▓█ MODULE CLASS RESOLUTION █▓▒░
    $fullTypeSignal = Resolve-PathFromDictionary -Dictionary $manifestSignal -Path "@.FullType" | Select-Object -Last 1
    if ($signal.MergeSignalAndVerifyFailure($fullTypeSignal)) {
        $signal.LogCritical("❌ Failed to resolve FullType from module manifest.")
        return $signal
    }

    $className = $fullTypeSignal.GetResult()
    $isAlreadyLoadedSignal = Test-IsClassDefined -ClassName $className | Select-Object -Last 1
    if ($signal.MergeSignalAndVerifyFailure($isAlreadyLoadedSignal)) {
        $signal.LogCritical("❌ Class check failed for type: $className")
        return $signal
    }

    if ($isAlreadyLoadedSignal.GetResult()) {
        $signal.LogInformation("✅ Class '$className' already loaded; skipping import.")
    }
    else {
        $modNameSignal     = Resolve-PathFromDictionary -Dictionary $manifestSignal -Path "Name" | Select-Object -Last 1
        $relPathSignal     = Resolve-PathFromDictionary -Dictionary $manifestSignal -Path "RelativeFilePath" | Select-Object -Last 1
        $devPathSignal     = Resolve-PathFromDictionary -Dictionary $ConductionContext -Path "Environment.DevModulePath" | Select-Object -Last 1

        if (-not $signal.MergeSignalAndVerifySuccess(@($modNameSignal, $relPathSignal, $devPathSignal))) {
            $signal.LogCritical("❌ Required fields missing for module import.")
            return $signal
        }

        $modName = $modNameSignal.GetResult()
        $relPath = $relPathSignal.GetResult()
        $rootPath = $devPathSignal.GetResult()

        $fullModulePath = Join-Path (Join-Path $rootPath $relPath)

        # ░▒▓█ CHECK AND IMPORT MODULE █▓▒░
        $checkSignal = Test-ModuleLoaded -ModulesGraph $ConductionContext -ModuleName $modName | Select-Object -Last 1
        $signal.MergeSignal($checkSignal)

        if (-not $checkSignal.Success()) {
            try {
                Import-Module -Name $fullModulePath -ErrorAction Stop
                $regSignal = Register-ModuleLoaded -ModulesGraph $ConductionContext -ModuleName $modName -FullPath $fullModulePath -Version "1.0.0" | Select-Object -Last 1
                $signal.MergeSignal($regSignal)
                $signal.LogInformation("📦 Module '$modName' loaded successfully from '$fullModulePath'.")
            }
            catch {
                $signal.LogCritical("❌ Import failed for module '$modName': $($_.Exception.Message)")
                return $signal
            }
        }
        else {
            $signal.LogVerbose("✅ Module '$modName' already loaded.")
        }
    }

    $signal.SetResult($jacketSignal)
    return $signal
}
