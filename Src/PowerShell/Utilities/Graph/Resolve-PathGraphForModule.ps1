function Resolve-PathGraphForModule {
    param (
        [Parameter(Mandatory)][string]$WirePath,
        [Parameter()][object]$Environment
    )

    $opSignal = [Signal]::Start("Resolve-PathGraphForModule:$WirePath") | Select-Object -Last 1

    try {
        # ░▒▓█ VERIFY WIREPATH FORMAT █▓▒░
        $segments = $WirePath -split '\.'
        if ($segments.Count -lt 4) {
            $opSignal.LogCritical("❌ WirePath must follow format Project.Collection.Kind.Type[.Slot][.Key]")
            return $opSignal
        }

        # ░▒▓█ EXTRACT PATH COMPONENTS █▓▒░
        $project    = $segments[0]
        $collection = $segments[1]
        $kind       = $segments[2]
        $type       = $segments[3]
        $slot       = if ($segments.Count -ge 5) { $segments[4] } else { $null }
        $key        = if ($segments.Count -ge 6) { $segments[5] } else { $null }

        $moduleStem = "$kind`_$type"
        $moduleName = "$moduleStem.psd1"

        # ░▒▓█ PATH CONSTRUCTION █▓▒░
        $folderSegments = @("$project.$collection", 'Src', $kind, $type, 'PowerShell')
        $relativeFolderPath = [System.IO.Path]::Combine($folderSegments)
        $relativeFilePath   = Join-Path $relativeFolderPath $moduleName

        # ░▒▓█ BUILD SIGNALIZED GRAPH █▓▒░
        $graph = [Graph]::new($Environment)
        $graph.Start()

        $nodeSignal = [Signal]::Start("Module:$moduleStem") | Select-Object -Last 1
        $nodeSignal.SetResult([ordered]@{
            Project            = $project
            Collection         = $collection
            Kind               = $kind
            Type               = $type
            Slot               = $slot
            Key                = $key
            Name               = $moduleName
            ModuleStem         = $moduleStem
            VirtualPath        = $WirePath
            FullType           = $moduleStem
            RelativeFolderPath = $relativeFolderPath
            RelativeFilePath   = $relativeFilePath
            HydrationIntent    = @(
                @{
                    ConductionWirePath = "XYZ.Placeholder"
                    TargetPath         = "Modules.$moduleStem"
                    SourcePath         = $relativeFilePath
                    Format             = "psd1"
                    Timing             = "Sequential"
                }
            )
        })

        $graph.RegisterSignal("Manifest", $nodeSignal)
        $graph.Finalize()

        $opSignal.SetResult($graph)
        $opSignal.LogInformation("✅ Module formula graph resolved from WirePath: $WirePath")
    }
    catch {
        $opSignal.LogCritical("🔥 Exception while resolving module graph: $($_.Exception.Message)")
    }

    return $opSignal
}
