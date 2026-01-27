function Invoke-ST {
    [CmdletBinding()]
    param (
        [object]$Environment,
        [object]$ConductionPlanRoute,
        [object]$ConductionContext
    )

    function Invoke-PlanWithOptionalContext {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [Signal]$Signal,   # Signal with Conductor.Signal in Jacket

            [Parameter(Mandatory)]
            [object]$Overlay
        )

        $opSignal = [Signal]::Start("Resolve-ConductionPlanRoute", $Signal) | Select-Object -Last 1

        $opSignal.LogInformation("🧭 Resolving ConductionPlanRoute from RouteOverlay.")

        # ──────────────────────────────────────────────────────────────────────
        # Base mapping (overlay expected to provide name/path)
        # ──────────────────────────────────────────────────────────────────────
        $ConductionPlanMapping = [pscustomobject]@{
            Adapter   = 'Storage.Content'
            Activity  = 'Read'
            Container = 'Plans'
            Format    = 'Json'
            Key             = 'Plans'
        }

        # ──────────────────────────────────────────────────────────────────────
        # Merge overlay plan source (required)
        # ──────────────────────────────────────────────────────────────────────
        $mergeSignal = Invoke-TransformCondenser `
            -Activity 'Merge' `
            -Signal $Signal `
            -Base $ConductionPlanMapping `
            -Overlay $Overlay `
            -MergeArrayHandling "Merge" `
        | Select-Object -Last 1

        if ($opSignal.MergeSignalAndVerifyFailure(@($mergeSignal))) {
            $opSignal.LogCritical("⚠️ Failed to merge RouteOverlay into ConductionPlanMapping.")
            return $opSignal
        }

        $ConductionPlanMapping = $mergeSignal.GetResult()

        $InvokeConductionMapping = [PSCustomObject]@{
            Name                = "Process Grid"
            Description         = "Uses the Conduit to run a Condenser.Conduction  on each item in the Graph made from previous step."
            Adapter       = "Condenser.Conduit"
            Activity      = "Process"
            ForEachPath         = "*"

            ForEachInTemplate = "*"
            ForEachIn         = ""

            ForEachAdapter        = "Condenser.Conduction"
            ForEachActivity       = "ST"
            SourceFormat                = "Json"
        }


        # ──────────────────────────────────────────────────────────────────────
        # Wrap as Memory.Generate plan
        # ──────────────────────────────────────────────────────────────────────
        $ConductionPlan = [pscustomobject]@{
            ReturnItemSignal = $true
            Mappings         = @($ConductionPlanMapping, $InvokeConductionMapping)
        }

        # ──────────────────────────────────────────────────────────────────────
        # Execute Memory.Generate
        # ──────────────────────────────────────────────────────────────────────
        $TargetSignal = [Signal]::Start("Resolve-ConductionPlanRoute.Target", $opSignal) | Select-Object -Last 1

        $sourceSignal = Invoke-CondenserAdapter `
            -Slot "Memory" `
            -Activity "Generate" `
            -Signal $Signal `
            -Plan $ConductionPlan `
            -ItemSignal $TargetSignal `
        | Select-Object -Last 1

        if ($opSignal.MergeSignalAndVerifyFailure(@($sourceSignal))) {
            $opSignal.LogCritical("⚠️ Memory.Generate failed while resolving ConductionPlan.")
            return $opSignal
        }
<#
        # Extract resolved plan
        $planSignal = Resolve-PathFromDictionary `
            -Dictionary $sourceSignal `
            -Path "@.*.#.Plan" `
            -SignalLevel "Critical" `
        | Select-Object -Last 1

        if ($opSignal.MergeSignalAndVerifyFailure(@($planSignal))) {
            $opSignal.LogCritical("⚠️ Failed to resolve '@.*.#.Plan' from Memory.Generate result.")
            return $opSignal
        }

        $opSignal.SetResult($planSignal.GetResult())
#>
        $opSignal.SetResult($sourceSignal.GetResult())
        $opSignal.LogInformation("✅ Conduction plan resolved successfully.")
        return $opSignal
    }


    function Resolve-PlanContentGeneration {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [Signal]$Signal,   # Signal with Conductor.Signal in Jacket

            [Parameter(Mandatory)]
            [object]$Overlay,

            # When true, run the merged content as a mapping through the Memory -> Generate condenser.
            [bool]$GenerateMemory
        )

        $opSignal = [Signal]::Start("Resolve-ConductionPlanRoute", $Signal) | Select-Object -Last 1

        $opSignal.LogInformation("🧭 Resolving ConductionPlanRoute from RouteOverlay.")

        # ──────────────────────────────────────────────────────────────────────
        # Base mapping (overlay expected to provide name/path)
        # ──────────────────────────────────────────────────────────────────────
        $ConductionPlanMapping = [pscustomobject]@{
            SourceAdapter   = 'Storage.Content'
            SourceActivity  = 'Read'
            SourceContainer = 'Plans'
            SourceFormat    = 'Json'
        }

        # ──────────────────────────────────────────────────────────────────────
        # Merge overlay (required)
        # ──────────────────────────────────────────────────────────────────────
        $mergeSignal = Invoke-TransformCondenser `
            -Activity 'Merge' `
            -Signal $Signal `
            -Base $ConductionPlanMapping `
            -Overlay $Overlay `
            -MergeArrayHandling "Merge" `
        | Select-Object -Last 1

        if ($opSignal.MergeSignalAndVerifyFailure(@($mergeSignal))) {
            $opSignal.LogCritical("⚠️ Failed to merge RouteOverlay into ConductionPlanMapping.")
            return $opSignal
        }

        $ConductionPlanMapping = $mergeSignal.GetResult()

        if (-not $GenerateMemory)
        {
            $opSignal.SetResult($mergeSignal.GetResult($true))
            return $opSignal
        }
        # ──────────────────────────────────────────────────────────────────────
        # Wrap as Memory.Generate plan
        # ──────────────────────────────────────────────────────────────────────
        $ConductionPlan = [pscustomobject]@{
            ReturnItemSignal = $true
            Mappings         = @($ConductionPlanMapping)
        }

        # ──────────────────────────────────────────────────────────────────────
        # Execute Memory.Generate
        # ──────────────────────────────────────────────────────────────────────
        $TargetSignal = [Signal]::Start("Resolve-ConductionPlanRoute.Target", $opSignal) | Select-Object -Last 1

        $sourceSignal = Invoke-CondenserAdapter `
            -Slot "Memory" `
            -Activity "Generate" `
            -Signal $Signal `
            -Plan $ConductionPlan `
            -ItemSignal $TargetSignal `
        | Select-Object -Last 1

        if ($opSignal.MergeSignalAndVerifyFailure(@($sourceSignal))) {
            $opSignal.LogCritical("⚠️ Memory.Generate failed while resolving ConductionPlan.")
            return $opSignal
        }
<#
        # Extract resolved plan
        $planSignal = Resolve-PathFromDictionary `
            -Dictionary $sourceSignal `
            -Path "@.*.#.Plan" `
            -SignalLevel "Critical" `
        | Select-Object -Last 1

        if ($opSignal.MergeSignalAndVerifyFailure(@($planSignal))) {
            $opSignal.LogCritical("⚠️ Failed to resolve '@.*.#.Plan' from Memory.Generate result.")
            return $opSignal
        }

        $opSignal.SetResult($planSignal.GetResult())
#>
        $opSignal.SetResult($sourceSignal.GetResult())
        $opSignal.LogInformation("✅ Conduction plan resolved successfully.")
        return $opSignal
    }

function Resolve-ConductionContext {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [Signal]$Signal,

        [object]$ConductionContext,
        [object]$ConductionContextOverlay
    )

    # ░▒▓█ SIGNAL START █▓▒░
    $opSignal = [Signal]::Start("Resolve-ConductionContext", $Signal) | Select-Object -Last 1

    try {
        $opSignal.LogInformation("🧭 Resolving ConductionContext.")

        # Start from provided context if present, otherwise an empty object
        $context = if ($null -ne $ConductionContext) { $ConductionContext } else { [PSCustomObject]@{} }

        # Apply overlay if provided
        if ($null -ne $ConductionContextOverlay) {
            $opSignal.LogInformation("🧩 Applying ConductionContextOverlay (Transform.Merge).")

            $mergeSignal = Invoke-TransformCondenser `
                -Signal $Signal `
                -Activity "Merge" `
                -Base $context `
                -Overlay $ConductionContextOverlay `
                -MergeArrayHandling "Merge" `
            | Select-Object -Last 1

            if ($opSignal.MergeSignalAndVerifyFailure(@($mergeSignal))) {
                $opSignal.LogCritical("⚠️ Failed merging ConductionContextOverlay into ConductionContext.")
                return $opSignal
            }

            $context = $mergeSignal.GetResult()
        }
        else {
            $opSignal.LogInformation("ℹ️ No ConductionContextOverlay provided; using base ConductionContext as-is.")
        }

        $opSignal.SetResult($context)
        $opSignal.LogInformation("✅ ConductionContext resolved successfully.")
        return $opSignal
    }
    catch {
        $opSignal.LogCritical("❌ Exception in Resolve-ConductionContext: $($_.Exception.Message)")
        return $opSignal
    }
}

    # ░▒▓█ START WRAPPER SIGNAL █▓▒░
    $opSignal = [Signal]::Start("Start-SovereignTrust") | Select-Object -Last 1

    # Optionally run a test fusion session

    # Create a global console logger
    $Global:ConsoleLoggerInstance = [ConsoleLogger]::new()
    $Global:SignalTelemeter = [SignalTelemeter]::new()

    #    [object]$Environment,
    #    [object]$ConductionPlanRoute,
    #    [object]$ConductionContext

    $environmentSignal = [Signal]::Start("Environment", $opSignal) | Select-Object -Last 1
    $environmentSignal.SetResult($Environment)

    $environmentJacketSignal = [Signal]::Start("Environment", $opSignal) | Select-Object -Last 1
    $environmentJacketSignal.SetJacket($environmentSignal)

    $conduitSignal = Resolve-Conduit -EnvironmentJacketSignal $environmentJacketSignal | Select-Object -Last 1
    if ($opSignal.MergeSignalAndVerifyFailure(@($conduitSignal))) {
        return $opSignal
    }


    $conductor = $conduitSignal.GetResult()
    $conductorSignal = $conductor.Signal
    
    $conductorJacketSignal = [Signal]::Start("Conductor", $opSignal) | Select-Object -Last 1
    $conductorJacketSignal.SetJacket($conductorSignal)
    
    $conductionPlanRouteSignal = $null
    if ($ConductionPlanRoute) {
        #$conductionPlanRouteSignal = Resolve-PlanContentGeneration -Signal $conductorJacketSignal -Overlay $ConductionPlanRoute -GenerateMemory $true | Select-Object -Last 1
        $conductionPlanRouteSignal = Invoke-PlanWithOptionalContext -Signal $conductorJacketSignal -Overlay $ConductionPlanRoute  | Select-Object -Last 1
    }

    $ConductionContextSignal = $null
    if ($ConductionContext) {
        $ConductionContextSignal = Resolve-ConductionContext -Signal $conductorJacketSignal -ConductionContext $ConductionContext | Select-Object -Last 1

        if ($opSignal.MergeSignalAndVerifyFailure($ConductionContextSignal)) {
            
        }
    }

    # Now Fire off Task into the $conduitSignal which is what the Condenser.Conductor.Process does when it loads a conduit to run in a silo.
    if ($PlanRunConfig) {
        Invoke-ST -ConductorSignal $conductorSignal -Plan $PlanRunConfig -ConfigContext $PlanConfigContext
    }


    # Moved the code below INTO Resolve-Conduit, Need to modify down to what is required for Invoke-SDAFusion outside of loading the exterior from external scripts.
    return $opSignal

    $bondingConductorSignal = Resolve-Conductor -Signal $opSignal | Select-Object -Last 1
    if ($opSignal.MergeSignalAndVerifyFailure(@($bondingConductorSignal))) {
        return $opSignal
    }

    $bondingConductor = $bondingConductorSignal.GetResult()

    $ConductorSignal = [Signal]::Start("EmbeddedFabRequest", $opSignal) | Select-Object -Last 1
    $ConductorSignal.SetJacket($bondingConductor.Signal)


    # Hardwired initiation point of content adapter pointed to local storage - review pattern, should probably be passed in.
    $ContentRootPathSignal = Resolve-PathFromDictionary -Dictionary $Environment -Path "ContentRootPath" | Select-Object -Last 1
    $virtualPath = "SovereignTrust.Adapters.Storage.EmbeddedFileSystem.Content.Persistent.Read"

    $EmbeddedFileSystemConfig = [PSCustomObject]@{

        VirtualPath = $virtualPath
        Addresses   = @($ContentRootPathSignal.GetResult())
    }

    $EmbeddedFabRequestSignal = [Signal]::Start("EmbeddedFabRequest", $opSignal) | Select-Object -Last 1
    $EmbeddedFabRequestSignal.SetResult($EmbeddedFileSystemConfig)
    $EmbeddedFabRequestSignal.SetJacket($bondingConductor.Signal)

    $ItemSignal = [Signal]::Start("EmbeddedFabRequest", $opSignal) | Select-Object -Last 1
    $ItemSignal.SetJacket($EmbeddedFabRequestSignal)

    $FabResult = Invoke-CondenserAdapter -Slot "Fab" -Signal $EmbeddedFabRequestSignal -ItemSignal $ItemSignal


    $EnvironmentSignal = Resolve-Environment -ConductorSignal $ConductorSignal -Environment $Environment | Select-Object -Last 1
    $Environment = $EnvironmentSignal.GetResult()
    $ConductionPlanRoute = Resolve-ConductionPlanRoute -BondingConductor $bondingConductor -RouteOverlay $ConductionPlanRoute | Select-Object -Last 1
    $ConductionContext = Resolve-ConductionContext -BondingConductor $bondingConductor -ConductionContextOverlay $ConductionContext | Select-Object -Last 1

    Add-PathToDictionary -Dictionary $opSignal -Path "*.#.Environment" -Value $Environment
    Add-PathToDictionary -Dictionary $opSignal -Path "*.#.BondingConductor" -Value $bondingConductor
    $opSignal.SetReversePointer($bondingConductorSignal)

    # Invoke a plan to start the conductor using the fabcondenser

    if ($PlanRunConfig) {
        $PlanRunConfig = Resolve-Plan -SourcePath 'Request' -SourceName 'Requests' -Config $PlanRunConfig
        $PlanConfigContext = Resolve-ConfigContext -ConfigContext $PlanConfigContext
        $PlanEnvironment = Resolve-Environment -Environment $Environment -ServiceRole "Request-Client"
        Invoke-ST -Environment $PlanEnvironment -Plan $PlanRunConfig -ConfigContext $PlanConfigContext
    }


    #    Start-STCSessionHost -RunInline $true

    <#
# Wire it into Signal system
$Global:SignalTelemeter = {
    param($signal, $entry)
    $Global:ConsoleLoggerInstance.Log($entry.Level, $entry.Message, $entry.Exception)
}
    #>
    #$opSignal = [Conductor]::Start($HostConductor, $ConductionSignal) | Select-Object -Last 1

    #   $bondingConductor = New-Conductor -HostConductor $null -ConductionSignal $signal


    <#
     $DependenciesPath = "$PSScriptRoot\Packages"
     
    if (-not (Test-Path -Path $DependenciesPath)) {
        New-Item -Path $DependenciesPath -ItemType Directory
    }
#>
    #    Initialize-EnvironmentDependenciesSignal -TempLibraryFolder  $DependenciesPath



    #    $sessionName = ([guid]::NewGuid()).ToString()
    #    $startHostSignal = Start-STCSessionHost -SessionName $sessionName -RunInline $true | Select-Object -Last 1


    #    $x = $startHostSignal.GetResult()
    #$transferSignal = Convert-ImagesWithNConvert -InputFolder "M:\SDA\Projects\Pulses" -OutputFolder "M:\SDA\Publish\Pulses" -ResizeWidth 2688 | Select-Object -Last 1
    #$a = $transferSignal.GetResult()
    #return
    <#
$nodeSignal = Start-AtpNodeSession | Select-Object -Last 1
$NodeSession = $nodeSignal.GetResult()

$loginSignal = Invoke-AtpLogin -Handle "NeuralAlchemist@bddb.io" -Password "ioql-7w6e-va7h-3kwp" -NodeSession $NodeSession | Select-Object -Last 1
$session = $loginSignal.GetResult()

#$feedSignal = Invoke-AtpGetFeed  -Session $session -NodeSession $NodeSession -Did "at://did:plc:clhejj3qcuzj44ajyq7ctq4c/app.bsky.feed.generator/aaafi6watywx4" | Select-Object -Last 1

#$profileSignal = Invoke-AtpGetProfile -Session $session -NodeSession $NodeSession -Did "sdafeeds.bsky.social" | Select-Object -Last 1
#$feedsSignal = Invoke-AtpGetActorFeeds -Session $session -NodeSession $NodeSession -Did "sdafeeds.bsky.social" | Select-Object -Last 1


$authorFeedSignal = Invoke-AtpGetAuthorFeed -Session $session -NodeSession $NodeSession -Did "lyraflux.bsky.social" | Select-Object -Last 1
$authorFeedSignal = Invoke-AtpGetAuthorFeed -Session $session -NodeSession $NodeSession -Did "clarak222.bsky.social" | Select-Object -Last 1
$authorFeedSignal = Invoke-AtpGetAuthorFeed -Session $session -NodeSession $NodeSession -Did "doomboundsda.bsky.social" | Select-Object -Last 1
$authorFeedSignal = Invoke-AtpGetAuthorFeed -Session $session -NodeSession $NodeSession -Did "shadowphantomsda.bsky.social" | Select-Object -Last 1

$postSignal = Invoke-AtpPostNote -Session $session  -Message "Hello world Test" -NodeSession $NodeSession | Select-Object -Last 1

#>
}