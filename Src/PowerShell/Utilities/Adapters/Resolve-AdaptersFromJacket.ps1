<# This should be moved to be the core of the Invoke-FabricateAdapter method? #>
function Resolve-AdapterFromJacket {
    param (
        [Parameter(Mandatory = $true)]
        [Signal]$Signal,

        [Parameter(Mandatory)]
        [object]$ConductionContext,

        [Parameter(Mandatory)]
        [object]$Jacket
    )

    $opSignal = [Signal]::Start("ResolveAdapter:$($Jacket.Name)") | Select-Object -Last 1

    try {
        # ░▒▓█ RESOLVE VIRTUAL PATH █▓▒░
        $virtualPathSignal = Resolve-PathFromDictionary -Dictionary $Jacket -Path "@.VirtualPath" | Select-Object -Last 1
        if ($opSignal.MergeSignalAndVerifyFailure($virtualPathSignal)) {
            $opSignal.LogCritical("Jacket is missing a valid VirtualPath.")
            return $opSignal
        }

        $wirePath = $virtualPathSignal.GetResult()

        # ░▒▓█ LOAD MODULE MANIFEST GRAPH █▓▒░
        $moduleGraphSignal = Resolve-DependencyModuleFromGraph -Signal $Signal -ConductionContext $ConductionContext -WirePath $wirePath | Select-Object -Last 1
        if ($opSignal.MergeSignalAndVerifyFailure($moduleGraphSignal)) {
            $opSignal.LogCritical("Failed to load manifest from WirePath: $wirePath")
            return $opSignal
        }

        # ░▒▓█ RESOLVE CLASS TYPE FROM MANIFEST █▓▒░
        $typeSignal = Resolve-PathFromDictionary -Dictionary $moduleGraphSignal -Path "@.%.@.FullType" | Select-Object -Last 1
        if ($opSignal.MergeSignalAndVerifyFailure($typeSignal)) {
            $opSignal.LogCritical("Class name missing in manifest.")
            return $opSignal
        }

        $typeName = $typeSignal.GetResult()

        # ░▒▓█ RESOLVE CLASS TYPE FROM MANIFEST █▓▒░
        $instance = $null
        $error1 = $null
        $error2 = $null


        # ░▒▓█ INSTANCE CREATION █▓▒░
        if ($moduleGraphSignal.HasResult()) {
            $typeClass = $moduleGraphSignal.GetResult()
            while ($typeClass -is [Signal] -and $typeClass.HasResult()) {
                $typeClass = $typeClass.GetResult() | Select-Object -Last 1
            }

            if ($typeClass -is [Type]) {
                $instance = [System.Activator]::CreateInstance($typeClass)
            }
        }

        if ($opSignal.MergeSignalAndVerifyFailure($typeSignal)) {
            $opSignal.LogCritical("Class name missing in manifest.")
            return $opSignal
        }

        if ($null -eq $instance) {
            try {
                $instance = New-Object -TypeName $typeName -ErrorAction Stop
            }
            catch {
                $error1 = "Failed to instantiate type '$typeName': $_"
            }
        }

        if ($null -eq $instance) {
            try {
                $resolveFunctionName = "Resolve-$typeName"
                $instance = & $resolveFunctionName
            }
            catch {
                $error2 = "Failed to instantiate type '$typeName': $_"
            }
        }

        if ($null -eq $instance) {
            $opSignal.LogCritical($error1)
            $opSignal.LogCritical($error2)
            return $opSignal
        }

        # ░▒▓█ TODO: THIS SHOULD BE DONE EXTERNALLY USING THE GRAPH CONDENSER █▓▒░

        # ░▒▓█ MERGE $JACKET OVER $MANIFEST █▓▒░
        $manifestSignal = Resolve-PathFromDictionary -Dictionary $moduleGraphSignal -Path "@.%.@" | Select-Object -Last 1
        if ($opSignal.MergeSignalAndVerifyFailure($manifestSignal)) {
            $opSignal.LogCritical("Failed to extract Manifest dictionary from Graph.")
            return $opSignal
        }

        $mergeServiceSignal = Resolve-PathFromDictionary -Dictionary $ConductionContext -Path "%.*.#.Adapters.*.#.MappedCondenser.@.$.*.#.MergeCondenser.@" | Select-Object -Last 1
        if ($opSignal.MergeSignalAndVerifyFailure($mergeServiceSignal)) {
            $opSignal.LogCritical("MergeCondenser not available on ConductionContext.")
            return $opSignal
        }

        $mergeService = $mergeServiceSignal.GetResult()
        $mergedSignal = $mergeService.InvokeByParameter($manifestSignal.GetResult(), $Jacket, $true) | Select-Object -Last 1

        if ($opSignal.MergeSignalAndVerifyFailure($mergedSignal)) {
            $opSignal.LogWarning("Jacket-to-Manifest merge failed; continuing with original jacket.")
        }
        else {
            $Jacket = $mergedSignal.GetResult()
            $opSignal.LogInformation("🧬 Jacket successfully merged over Manifest.")
        }

        # ░▒▓█ CONSTRUCT METHOD (OPTIONAL) █▓▒░
        if ($instance -and ($instance | Get-Member -Name "Construct" -MemberType Method)) {
            $constructCall = $instance.Construct($Jacket)
            $constructSignal = $constructCall | Select-Object -Last 1

            if ($opSignal.MergeSignalAndVerifySuccess($constructSignal)) {
                $opSignal.LogInformation("✅ Adapter '$($Jacket.Name)' ($($Jacket.VirtualPath)) constructed successfully.")
            }
            else {
                $opSignal.LogWarning("Construct() failed on adapter '$($Jacket.Name)'.")
            }
        }
        else {
            $opSignal.LogVerbose("No Construct() method found for '$($Jacket.Name)'. ($($Jacket.VirtualPath)) Proceeding without initialization.")
        }

        # ░▒▓█ RESULT █▓▒░
            $opSignal.SetResult($instance)
        $opSignal.LogInformation("📦 Adapter '$($Jacket.Name)' resolved and returned successfully.")
    }
    catch {
        $opSignal.LogCritical("🔥 Exception during adapter resolution: $($_.Exception.Message)", $null, $_)
    }

    return $opSignal
}
