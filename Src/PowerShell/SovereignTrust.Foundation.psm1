$sgModuleName = 'SignalGraph'

if (-not (Get-Module -Name $sgModuleName)) {
    $sgPath = Join-Path $PSScriptRoot "../../../SignalGraph/Src/PowerShell/SignalGraph.psd1"
    Import-Module (Resolve-Path $sgPath).ProviderPath -Force
}

$abc = Get-Module -Name $sgModuleName
    # Import shared functions for Map Condensers

    $mapSharedPath = Join-Path $PSScriptRoot "Utilities/Adapters/Condenser/Map/MapCondenser.Shared.psm1"
    Import-Module (Resolve-Path $mapSharedPath).ProviderPath -Force


# Load all files (functions + classes)
. "$PSScriptRoot/Classes/Adapters/MappedStorageAdapter.ps1"
. "$PSScriptRoot/Classes/Adapters/MappedTokenAdapter.ps1"
. "$PSScriptRoot/Classes/Adapters/MappedAdapterTemplate.ps1"
. "$PSScriptRoot/Classes/Adapters/MappedCondenserAdapter.ps1"
. "$PSScriptRoot/Classes/Adapters/MappedConduitAdapter.ps1"
. "$PSScriptRoot/Classes/Adapters/MappedNetworkAdapter.ps1"
. "$PSScriptRoot/Classes/Adapters/MappedQuantumAdapter.ps1"
. "$PSScriptRoot/Classes/Conduction/Conduit.ps1"
. "$PSScriptRoot/Classes/Conduction/Conductor.ps1"

. "$PSScriptRoot/Classes/Adapters/Token/Token_Conduction.ps1"
. "$PSScriptRoot/Classes/Adapters/Token/Token_Environment.ps1"
. "$PSScriptRoot/Classes/Adapters/Token/Token_Formatter.ps1"
. "$PSScriptRoot/Classes/Adapters/Token/Token_Generator.ps1"
. "$PSScriptRoot/Classes/Adapters/Token/Token_Navigator.ps1"
. "$PSScriptRoot/Classes/Adapters/Token/Token_Storage.ps1"


. "$PSScriptRoot/Classes/Adapters/BaseAdapter.ps1"
. "$PSScriptRoot/Classes/Adapters/Conduit.ps1"
. "$PSScriptRoot/Classes/Adapters/Condenser/FabCondenser.ps1"
. "$PSScriptRoot/Classes/Adapters/Condenser/ConductionCondenser.ps1"
. "$PSScriptRoot/Classes/Adapters/Condenser/GraphCondenser.ps1"
. "$PSScriptRoot/Classes/Adapters/Condenser/GlobalCondenser.ps1"
. "$PSScriptRoot/Classes/Adapters/Condenser/GridCondenser.ps1"
. "$PSScriptRoot/Classes/Adapters/Condenser/HydrationCondenser.ps1"
. "$PSScriptRoot/Classes/Adapters/Condenser/MapCondenser.ps1"
. "$PSScriptRoot/Classes/Adapters/Condenser/MemoryCondenser.ps1"
. "$PSScriptRoot/Classes/Adapters/Condenser/MergeCondenser.ps1"
. "$PSScriptRoot/Classes/Adapters/Condenser/TokenCondenser.ps1"
. "$PSScriptRoot/Classes/Adapters/Storage/Storage_EmbeddedFileSystem.ps1"
. "$PSScriptRoot/Classes/Adapters/UX/ConsoleLogger.ps1"

#. "$PSScriptRoot/Utilities/New-Conductor.ps1"
. "$PSScriptRoot/Utilities/Adapters/Storage/Invoke-EmbeddedFileSystem_ReadObject.ps1"

. "$PSScriptRoot/Utilities/Adapters/New-MappedCondenserAdapterFromGraph.ps1"
. "$PSScriptRoot/Utilities/Adapters/Register-AdapterToMappedSlot.ps1"
. "$PSScriptRoot/Utilities/Adapters/Register-MappedAdapter.ps1"
. "$PSScriptRoot/Utilities/Adapters/Register-ModuleLoaded.ps1"
. "$PSScriptRoot/Utilities/Adapters/Resolve-AdaptersFromJacket.ps1"
. "$PSScriptRoot/Utilities/Adapters/Resolve-ConductorAdapters.ps1"
. "$PSScriptRoot/Utilities/Adapters/Resolve-DependencyModuleFromGraph.ps1"
. "$PSScriptRoot/Utilities/Adapters/Test-ModuleLoaded.ps1"
. "$PSScriptRoot/Utilities/Adapters/Condenser/Fab/Invoke-FabCondenser.ps1"
. "$PSScriptRoot/Utilities/Adapters/Condenser/Fab/Invoke-GraphFabCondenser.ps1"
. "$PSScriptRoot/Utilities/Adapters/Condenser/Fab/Resolve-ModuleFromAdapter.ps1"
. "$PSScriptRoot/Utilities/Adapters/Condenser/Grid/Invoke-GridCondenser.ps1"
. "$PSScriptRoot/Utilities/Adapters/Condenser/Graph/Invoke-GraphCondenser.ps1"
. "$PSScriptRoot/Utilities/Adapters/Condenser/Conduction/Invoke-ConductionCondenser.ps1"
. "$PSScriptRoot/Utilities/Adapters/Condenser/Conduction/Invoke-GraphConductionCondenser.ps1"
#. "$PSScriptRoot/Utilities/Adapters/Condenser/Graph/Invoke-Graph.ps1"
. "$PSScriptRoot/Utilities/Adapters/Condenser/Global/Invoke-GlobalCondenser.ps1"
. "$PSScriptRoot/Utilities/Adapters/Condenser/Token/Invoke-TokenCondenser.ps1"
. "$PSScriptRoot/Utilities/Adapters/Condenser/Global/Resolve-GlobalTokenOverrideForProperty.ps1"
. "$PSScriptRoot/Utilities/Adapters/Condenser/Hydration/Apply-HydrationToGraph.ps1"
. "$PSScriptRoot/Utilities/Adapters/Condenser/Hydration/Convert-VirtualPathToWirePath.ps1"
. "$PSScriptRoot/Utilities/Adapters/Condenser/Hydration/Ensure-HydrationIntentInSignal.ps1"
. "$PSScriptRoot/Utilities/Adapters/Condenser/Hydration/Invoke-GraphHydrationCondenser.ps1"
. "$PSScriptRoot/Utilities/Adapters/Condenser/Hydration/Invoke-HydrationCondenser.ps1"
. "$PSScriptRoot/Utilities/Adapters/Condenser/Hydration/Read-HydrationFile.ps1"
. "$PSScriptRoot/Utilities/Adapters/Condenser/Hydration/Resolve-GraphHydrationQueue.ps1"
. "$PSScriptRoot/Utilities/Adapters/Condenser/Hydration/Resolve-HydrationSourcePath.ps1"
. "$PSScriptRoot/Utilities/Adapters/Condenser/Memory/Invoke-HotPathResolution.ps1"
. "$PSScriptRoot/Utilities/Adapters/Condenser/Memory/Invoke-MemoryCondenser.ps1"
. "$PSScriptRoot/Utilities/Adapters/Condenser/Memory/Invoke-PathHydration.ps1"
. "$PSScriptRoot/Utilities/Adapters/Condenser/Merge/Merge-CondenserCore.ps1"
. "$PSScriptRoot/Utilities/Adapters/Condenser/Token/Invoke-HydrateTokenCondenser.ps1"
. "$PSScriptRoot/Utilities/Adapters/Storage/Resolve-ModulePathFromAdapter.ps1"

. "$PSScriptRoot/Utilities/Adapters/Token/Invoke-MappedTokenAdapter.ps1"
. "$PSScriptRoot/Utilities/Adapters/Token/Invoke-TokenEnvironment.ps1"
. "$PSScriptRoot/Utilities/Adapters/Token/Invoke-TokenFormatter.ps1"
. "$PSScriptRoot/Utilities/Adapters/Token/Invoke-TokenFormatterFilePath.ps1"

. "$PSScriptRoot/Utilities/Conduction/Complete-Conduction.ps1"
. "$PSScriptRoot/Utilities/Conduction/ConductionCoreFunctions.ps1"
. "$PSScriptRoot/Utilities/Conduction/ConductionPhaseFunctions.ps1"
. "$PSScriptRoot/Utilities/Conduction/Convert-AgentAdaptersToConductor.ps1"
. "$PSScriptRoot/Utilities/Conduction/Get-AgentForConductor.ps1"
. "$PSScriptRoot/Utilities/Conduction/Invoke-Conduction.ps1"
. "$PSScriptRoot/Utilities/Conduction/Resolve-RelativePathFromWirePath-na.ps1"
. "$PSScriptRoot/Utilities/Conduction/Start-Conduction.ps1"
. "$PSScriptRoot/Utilities/Conduction/Start-SovereignTrust.ps1"
. "$PSScriptRoot/Utilities/Conduction/Start-BondingConduction.ps1"
. "$PSScriptRoot/Utilities/Conduction/Start-BondingConductor.ps1"
. "$PSScriptRoot/Utilities/Graph/Convert-GraphToJson.ps1"
. "$PSScriptRoot/Utilities/Graph/Convert-JsonToGraph.ps1"
. "$PSScriptRoot/Utilities/Graph/Resolve-PathGraph.ps1"
. "$PSScriptRoot/Utilities/Graph/Resolve-PathGraphCondenserAdapter.ps1"
. "$PSScriptRoot/Utilities/Graph/Resolve-PathGraphTokenAdapter.ps1"
. "$PSScriptRoot/Utilities/Graph/Resolve-PathGraphForConduction.ps1"
. "$PSScriptRoot/Utilities/Graph/Resolve-ModulePathSignal.ps1"
. "$PSScriptRoot/Utilities/Graph/Resolve-PathGraphForPublisher.ps1"
. "$PSScriptRoot/Utilities/IO/LocalFileSystem/Read-JsonFileAsSignal.ps1"
. "$PSScriptRoot/Utilities/IO/LocalFileSystem/Wait-ForFileUnlock.ps1"
. "$PSScriptRoot/Utilities/Json/Convert-JsonToHashtable.ps1"
. "$PSScriptRoot/Utilities/Json/Get-DictionaryValue.ps1"
. "$PSScriptRoot/Utilities/Json/Get-JsonObjectFromFile.ps1"
. "$PSScriptRoot/Utilities/Json/Get-VirtualValueFromJson.ps1"
. "$PSScriptRoot/Utilities/Json/Resolve-FilteredArrayItem.ps1"
. "$PSScriptRoot/Utilities/Json/Resolve-PathFromDictionaryNoSignal.ps1"
. "$PSScriptRoot/Utilities/Json/Resolve-RegexPlaceholders.ps1"
. "$PSScriptRoot/Utilities/Json/Set-DictionaryValue.ps1"
. "$PSScriptRoot/Utilities/Json/Test-Paths.ps1"
. "$PSScriptRoot/Utilities/Tooling/Ensure-DotNetLibraryFromNuget.ps1"
. "$PSScriptRoot/Utilities/Tooling/Evaluate-AgainstDoctrine.ps1"
. "$PSScriptRoot/Utilities/Tooling/Invoke-TestGraph.ps1"
. "$PSScriptRoot/Utilities/Tooling/Invoke-TraceSignalTree.ps1"
. "$PSScriptRoot/Utilities/Tooling/Invoke-VisualizeSignalTreeTrace.ps1"
. "$PSScriptRoot/Utilities/Tooling/SovereignTrust.Foundation.Diagrams.ps1"
. "$PSScriptRoot/Utilities/Tooling/Test-IsClassDefined.ps1"

# Export public utility functions
Export-ModuleMember -Function New-MappedCondenserAdapterFromGraph
Export-ModuleMember -Function Register-AdapterToMappedSlot
Export-ModuleMember -Function Register-MappedAdapter
Export-ModuleMember -Function Register-ModuleLoaded
Export-ModuleMember -Function Resolve-AdaptersFromJacket
Export-ModuleMember -Function Resolve-ConductorAdapters
Export-ModuleMember -Function Resolve-DependencyModuleFromGraph
Export-ModuleMember -Function Test-ModuleLoaded
Export-ModuleMember -Function Invoke-GridCondenser
Export-ModuleMember -Function Invoke-TokenCondenser
Export-ModuleMember -Function Invoke-GraphCondenser
Export-ModuleMember -Function Invoke-ConductionCondenser
Export-ModuleMember -Function Invoke-GraphConductionCondenser
Export-ModuleMember -Function Invoke-Graph
Export-ModuleMember -Function Apply-HydrationToGraph
Export-ModuleMember -Function Convert-VirtualPathToWirePath
Export-ModuleMember -Function Ensure-HydrationIntentInSignal
Export-ModuleMember -Function Invoke-GraphHydrationCondenser
Export-ModuleMember -Function Invoke-HydrationCondenser
Export-ModuleMember -Function Invoke-GlobalCondenser
Export-ModuleMember -Function Read-HydrationFile
Export-ModuleMember -Function Resolve-GraphHydrationQueue
Export-ModuleMember -Function Resolve-HydrationSourcePath
Export-ModuleMember -Function Invoke-HotPathResolution
Export-ModuleMember -Function Invoke-MemoryCondenser
Export-ModuleMember -Function Invoke-PathHydration
Export-ModuleMember -Function Merge-CondenserCore
Export-ModuleMember -Function Complete-Conduction
Export-ModuleMember -Function ConductionCoreFunctions
Export-ModuleMember -Function ConductionPhaseFunctions
Export-ModuleMember -Function Convert-AgentAdaptersToConductor
Export-ModuleMember -Function Get-AgentForConductor
Export-ModuleMember -Function Invoke-Conduction
Export-ModuleMember -Function Resolve-RelativePathFromWirePath-na
Export-ModuleMember -Function Start-Conduction
Export-ModuleMember -Function Start-BondingConduction
Export-ModuleMember -Function Start-BondingConductor
Export-ModuleMember -Function Start-SovereignTrust
Export-ModuleMember -Function Convert-GraphToJson
Export-ModuleMember -Function Convert-JsonToGraph
Export-ModuleMember -Function Resolve-PathGraph
Export-ModuleMember -Function Resolve-PathGraphCondenserAdapter
Export-ModuleMember -Function Resolve-PathGraphForConduction
Export-ModuleMember -Function Resolve-ModulePathSignal
Export-ModuleMember -Function Resolve-PathGraphForPublisher
Export-ModuleMember -Function Read-JsonFileAsSignal
Export-ModuleMember -Function Wait-ForFileUnlock
Export-ModuleMember -Function Convert-JsonToHashtable
Export-ModuleMember -Function Get-DictionaryValue
Export-ModuleMember -Function Get-JsonObjectFromFile
Export-ModuleMember -Function Get-VirtualValueFromJson
Export-ModuleMember -Function Resolve-FilteredArrayItem
Export-ModuleMember -Function Resolve-PathFromDictionaryNoSignal
Export-ModuleMember -Function Resolve-RegexPlaceholders
Export-ModuleMember -Function Set-DictionaryValue
Export-ModuleMember -Function Test-Paths
Export-ModuleMember -Function Ensure-DotNetLibraryFromNuget
Export-ModuleMember -Function Evaluate-AgainstDoctrine
Export-ModuleMember -Function Invoke-TestGraph
Export-ModuleMember -Function Invoke-TraceSignalTree
Export-ModuleMember -Function Invoke-VisualizeSignalTreeTrace
Export-ModuleMember -Function SovereignTrust.Foundation.Diagrams
Export-ModuleMember -Function Test-IsClassDefined
Export-ModuleMember -Function New-Conductor
Export-ModuleMember -Function Invoke-HydrateTokenCondenser
#        $bondingConductor = New-Conductor -HostConductor $null
