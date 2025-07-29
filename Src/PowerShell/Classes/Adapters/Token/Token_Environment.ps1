class Token_Environment {
    [Signal]$Signal
    [Conductor]$Conductor
    [MappedTokenAdapter]$MappedAdapter
    [object]$Jacket

    Token_Environment() {
    }


    static [Token_Environment] Start([MappedTokenAdapter]$mappedAdapter, [Conductor]$conductor) {
        $instance = [Token_Environment]::new()
        $instance.MappedAdapter = $mappedAdapter
        $instance.Conductor = $conductor
        $instance.Signal = [Signal]::Start("GraphCondenser")
        return $instance
    }

    [Signal] Construct([object]$dictionary) {
        $opSignal = [Signal]::Start("Construct-EmbeddedFileSystem") | Select-Object -Last 1

        try {
            if ($null -eq $dictionary) {
                return $opSignal.LogCritical("Cannot construct EmbeddedFileSystem — provided dictionary is null.")
            }

            $this.Jacket = $dictionary
            $opSignal.LogInformation("EmbeddedFileSystem constructed successfully with provided jacket.")
        }
        catch {
            $opSignal.LogCritical("Error constructing EmbeddedFileSystem: $_")
        }

        return $opSignal
    }

    [Signal] ReadObjectAsJson([string]$virtualPath) {
        $opSignal = [Signal]::Start("EmbeddedFileSystem.ReadObjectAsJson") | Select-Object -Last 1

        try {
            $pathWithExtension = "$virtualPath.json"
            $jsonSignal = Get-JsonObjectFromFile -RootFolder $this.Jacket.Address -VirtualPath $pathWithExtension | Select-Object -Last 1
            $opSignal.MergeSignal($jsonSignal)

            if ($jsonSignal.Success()) {
                $opSignal.SetResult($jsonSignal.GetResult())
                $opSignal.LogInformation("📄 JSON content read from embedded file system: $pathWithExtension")
            } else {
                $opSignal.LogWarning("⚠️ Failed to read JSON from: $pathWithExtension")
            }
        }
        catch {
            $opSignal.LogCritical("🔥 Exception in EmbeddedFileSystem.ReadObjectAsJson: $($_.Exception.Message)")
        }

        return $opSignal
    }
}
