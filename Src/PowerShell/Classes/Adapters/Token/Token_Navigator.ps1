class Token_Navigator {
    [Signal]$Signal
    [Conductor]$Conductor
    [MappedTokenAdapter]$MappedAdapter
    [object]$Jacket

    Token_Navigator() {
    }

    static [Token_Navigator] Start([MappedTokenAdapter]$mappedAdapter, [Conductor]$conductor) {
        $instance = [Token_Navigator]::new()
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

[Signal] Invoke([object]$Path, [object]$Plan) {
    $opSignal = [Signal]::Start("Token_Navigator.Invoke") | Select-Object -Last 1

    try {
        $resultSignal = Invoke-TokenNavigator -Conductor $this.Conductor -Conduit $null -Path $Path -Plan $Plan | Select-Object -Last 1
        $opSignal.MergeSignal($resultSignal)

        if ($resultSignal.Success()) {
            $opSignal.SetResult($resultSignal.GetResult())
            $opSignal.LogInformation("✅ Token navigator path '$Path' resolved successfully.")
        } else {
            $opSignal.LogWarning("⚠️ Token navigator path '$Path' failed to resolve.")
        }
    }
    catch {
        $opSignal.LogCritical("🔥 Exception in Token_Navigator.Invoke: $($_.Exception.Message)")
    }

    return $opSignal
}

}
