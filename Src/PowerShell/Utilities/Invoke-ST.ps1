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

        $opSignal = [Signal]::Start("Invoke-ST: Conduction Runner", $Signal) | Select-Object -Last 1
        
        # Acts as the Conduction Signal with the Conductor
        $opSignal.SetJacket($Signal)
        $opSignal.LogInformation("Resolving ConductionPlanRoute from RouteOverlay.")

        # ──────────────────────────────────────────────────────────────────────
        # Base mapping (overlay expected to provide name/path)
        # ──────────────────────────────────────────────────────────────────────
        $ConductionPlanMapping = [pscustomobject]@{
            Adapter   = 'Storage.Content'
            Activity  = 'Read'
            Container = 'Plans'
            Format    = 'Json'
            Key       = 'Plans'
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
            $opSignal.LogCritical("Failed to merge RouteOverlay into ConductionPlanMapping.")
            return $opSignal
        }

        $ConductionPlanMapping = $mergeSignal.GetResult()

        $InvokeConductionMapping = [PSCustomObject]@{
            Name              = "Process Grid"
            Description       = "Uses the Conduit to run a Condenser.Conduction  on each item in the Graph made from previous step."
            Adapter           = "Condenser.Conduit"
            Activity          = "Process"
            ForEachPath       = "*"

            ForEachInTemplate = "*"
            ForEachIn         = ""

            ForEachAdapter    = "Condenser.Conduction"
            ForEachActivity   = "ST"
            SourceFormat      = "Json"
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
        $TargetSignal = [Signal]::Start("Invoke-PlanWithOptionalContext", $opSignal) | Select-Object -Last 1

        $sourceSignal = Invoke-CondenserAdapter `
            -Slot "Memory" `
            -Activity "Generate" `
            -Signal $Signal `
            -Plan $ConductionPlan `
            -ItemSignal $TargetSignal `
        | Select-Object -Last 1

        if ($opSignal.MergeSignalAndVerifyFailure(@($sourceSignal))) {
            $opSignal.LogCritical("Memory.Generate failed while resolving ConductionPlan.")
            return $opSignal
        }

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
            $opSignal.LogCritical("Failed to merge RouteOverlay into ConductionPlanMapping.")
            return $opSignal
        }

        $ConductionPlanMapping = $mergeSignal.GetResult()

        if (-not $GenerateMemory) {
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
            $opSignal.LogCritical("Memory.Generate failed while resolving ConductionPlan.")
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
            $opSignal.LogCritical("Failed to resolve '@.*.#.Plan' from Memory.Generate result.")
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
                    $opSignal.LogCritical("Failed merging ConductionContextOverlay into ConductionContext.")
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
            $opSignal.LogCritical("Exception in Resolve-ConductionContext: $($_.Exception.Message)", $null, $_)
            return $opSignal
        }
    }

    # ░▒▓█ START WRAPPER SIGNAL █▓▒░
    $opSignal = [Signal]::Start("Start-SovereignTrust") | Select-Object -Last 1

    # Optionally run a test fusion session

    # Create a global console logger
    #    $Global:ConsoleLoggerInstance = [ConsoleLogger]::new()
    #    $Global:SignalTelemeter = [SignalTelemeter]::new()

    #    [object]$Environment,
    #    [object]$ConductionPlanRoute,
    #    [object]$ConductionContext

    $environmentSignal = [Signal]::Start("Environment", $opSignal) | Select-Object -Last 1
    $environmentSignal.SetJacketResult($Environment)

    $conduitSignal = Resolve-Conduit -EnvironmentSignal $environmentSignal | Select-Object -Last 1
    if ($opSignal.MergeSignalAndVerifyFailure(@($conduitSignal))) {
        return $opSignal
    }

    $conductor = $conduitSignal.GetResult()
    $conductorSignal = $conductor.Signal
    
    $conductorJacketSignal = [Signal]::Start("Conductor", $environmentSignal) | Select-Object -Last 1
    $conductorJacketSignal.SetJacket($conductorSignal)
    
    # Transfer the grid of content created during the environment generation to the base of the ConductorJacketSignal
    $conductorJacketSignal.SetPointer($environmentSignal.GetPointer())


    function TestTelemetry([object]$conductorJacketSignal) {
        $testOpSignal = [Signal]::Start("🎯 Start TestOpSignal", $environmentSignal) | Select-Object -Last 1
        $testOpSignal.AddTag("Mine")
        $testOpSignal.AddProperty("SignalId", ([guid]::NewGuid().ToString()))
        $testOpSignal.LogInformation("✅ Test Information Level");

        $entry = $testOpSignal.Entries | Select-Object -Last 1
        $entry.AddTag("Verbose")
        $entry.AddTag("IngestionScheduled")
        $entry.AddProperty("SignalId", ([guid]::NewGuid().ToString()))

        $testOpSignal.LogWarning("Test Warning Level");
        $entry = $testOpSignal.Entries | Select-Object -Last 1
        $entry.AddTag("Verbose")

        $testOpSignal.LogCritical("Test Critical Level", @("Verbose"));

        $signalMetaData = [PSCustomObject]@{
            OperationId = [guid]::NewGuid().ToString()
        }

        $testOpSignal.SetMeta($signalMetaData)

        try {
            not-real-function
        }
        catch {
            $testOpSignal.LogCritical("Exception in Invoke-ST: $($_.Exception.Message)", @("Urgent"), $_)
        }

        Invoke-Telemetry -Signal $conductorJacketSignal -ItemSignal $testOpSignal
        #Invoke-MappedAdapter -Adapter "Network.Telemetry" -Activity "EmitSignalFull" -Signal $conductorJacketSignal -Plan [pscustomobject]@{} -ItemSignal $testOpSignal
        ###################### 
    }

    #    TestTelemetry -conductorJacketSignal $conductorJacketSignal

    $conductionPlanRouteSignal = $null
    if ($ConductionPlanRoute) {
        $conductionPlanRouteSignal = Invoke-PlanWithOptionalContext -Signal $conductorJacketSignal -Overlay $ConductionPlanRoute  | Select-Object -Last 1
        Invoke-Telemetry -Signal $conductorJacketSignal -ItemSignal $conductionPlanRouteSignal
    }

    <#
    # Now Fire off Task into the $conduitSignal which is what the Condenser.Conductor.Process does when it loads a conduit to run in a silo.
    if ($PlanRunConfig) {
        Invoke-ST -ConductorSignal $conductorSignal -Plan $PlanRunConfig -ConfigContext $PlanConfigContext
    }

#>
    # Moved the code below INTO Resolve-Conduit, Need to modify down to what is required for Invoke-SDAFusion outside of loading the exterior from external scripts.
    return $opSignal

    <#
    $bondingConductorSignal = Resolve-Conductor -Signal $opSignal | Select-Object -Last 1
    if ($opSignal.MergeSignalAndVerifyFailure(@($bondingConductorSignal))) {
        return $opSignal
    }

    $bondingConductor = $bondingConductorSignal.GetResult()

    $ConductorSignal = [Signal]::Start("EmbeddedFabRequest", $opSignal) | Select-Object -Last 1
    $ConductorSignal.SetJacket($bondingConductor.Signal)

    # TODO: Move these harded coded items into the mapping as config or something that gets passed in.

    ###### System Content File Adapter
    # Hardwired initiation point of content adapter pointed to local storage - review pattern, should probably be passed in.
    $ContentRootPathSignal = Resolve-PathFromDictionary -Dictionary $Environment -Path "Config.ContentRootPath" | Select-Object -Last 1
    $virtualPath = "SovereignTrust.Adapters.Storage.EmbeddedFileSystem.Content.Persistent.Read"

    $Config = [PSCustomObject]@{

        VirtualPath = $virtualPath
        Addresses   = @($ContentRootPathSignal.GetResult())
    }

    $FabRequestSignal = [Signal]::Start("EmbeddedFabRequest", $opSignal) | Select-Object -Last 1
    $FabRequestSignal.SetResult($Config)
    $FabRequestSignal.SetJacket($bondingConductor.Signal)

    $ItemSignal = [Signal]::Start("EmbeddedFabRequest", $opSignal) | Select-Object -Last 1
    $ItemSignal.SetJacket($FabRequestSignal)

    $FabResult = Invoke-CondenserAdapter -Slot "Fab" -Signal $FabRequestSignal -ItemSignal $ItemSignal


    # One for System
    $virtualPath = "SovereignTrust.Adapters.Storage.EmbeddedFileSystem.System.Persistent.Read"

    $Config = [PSCustomObject]@{

        VirtualPath = $virtualPath
        Addresses   = @($ContentRootPathSignal.GetResult())
    }

    $FabRequestSignal = [Signal]::Start("EmbeddedFabRequest", $opSignal) | Select-Object -Last 1
    $FabRequestSignal.SetResult($Config)
    $FabRequestSignal.SetJacket($bondingConductor.Signal)

    $ItemSignal = [Signal]::Start("EmbeddedFabRequest", $opSignal) | Select-Object -Last 1
    $ItemSignal.SetJacket($FabRequestSignal)

    $FabResult = Invoke-CondenserAdapter -Slot "Fab" -Signal $FabRequestSignal -ItemSignal $ItemSignal


    $EnvironmentSignal = Resolve-Environment -ConductorSignal $ConductorSignal -Environment $Environment | Select-Object -Last 1
    $Environment = $EnvironmentSignal.GetResult()
    $ConductionPlanRoute = Resolve-ConductionPlanRoute -BondingConductor $bondingConductor -RouteOverlay $ConductionPlanRoute | Select-Object -Last 1
    $ConductionContext = Resolve-ConductionContext -BondingConductor $bondingConductor -ConductionContextOverlay $ConductionContext | Select-Object -Last 1

#>
    

    <#
        # Hardwired initiation point of Telemetry Service
    $AppInsightsAddressSignal = Resolve-PathFromDictionary -Dictionary $Environment -Path "Config.AppInsightsAddress" | Select-Object -Last 1
    $AppInsightsKeySignal = Resolve-PathFromDictionary -Dictionary $Environment -Path "Config.AppInsightsKey" | Select-Object -Last 1
    $virtualPath = "SovereignTrust.Adapters.Network.AzureApplicationInsights.Telemetry.Persistent.Run"

    $Config = [PSCustomObject]@{

        VirtualPath = $virtualPath
        Resource = $AppInsightsKeySignal.GetResult()
        Addresses   = @($AppInsightsAddressSignal.GetResult())
    }

    $FabRequestSignal = [Signal]::Start("AppInsightsFabRequest", $opSignal) | Select-Object -Last 1
    $FabRequestSignal.SetResult($Config)
    $FabRequestSignal.SetJacket($bondingConductor.Signal)

    $ItemSignal = [Signal]::Start("AppInsightsFabRequest", $opSignal) | Select-Object -Last 1
    $ItemSignal.SetJacket($FabRequestSignal)

    $FabResult = Invoke-CondenserAdapter -Slot "Fab" -Signal $FabRequestSignal -ItemSignal $ItemSignal
#>

    <#
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
        #>
}