function Invoke-TokenMemory {
    [CmdletBinding()]
    param (
        [MappedTokenAdapter]$MappedAdapter,
        [string]$Slot,
        # Conductor / environment signal that contains adapters (mapped attachments)
        [Parameter(Mandatory = $false)]
        [Signal]$Signal,

        [Parameter(Mandatory = $false)]
        [Signal]$ItemSignal,

        [object]$Plan,

        # Routing + IO parameters
        #        [Parameter(Mandatory = $false)]
        #        [string]$Adapter,

        [Parameter(Mandatory = $false)]
        [string]$Activity
    )

    if ($Conduit -and -not $Conduit.IsRunning) {
        throw "Conduction is not running. Cannot invoke Phase."
    }

    $opSignal = [Signal]::Start("Invoke-TokenMemory", $ItemSignal) | Select-Object -Last 1

    try {
        $Key = $Plan.Key

    
        if ([string]::IsNullOrWhiteSpace($Key)) {
            $opSignal.LogWarning("⚠️ Path is empty. Nothing to resolve.")
            return $opSignal
        }

        if ($Key -is [string] -and $Key.StartsWith("Memory.")) {
            $Key = $Key.Substring("Memory.".Length)
        }

        $segments = $Key -split '\.'

        $scope = 'Signal'
        $path = $null

        if ($segments.Count -gt 1) {
            $scope = $segments[0]
            $path = ($segments[1..($segments.Count - 1)] -join '.')
        }
        else {
            $path = $segments[0]
        }

        $default = $null
        $dictionary = $null

        # Split path|default if present
        if ($path -and $path -like '*|*')
         {
            $parts = $path -split '\|', 2
            $path = $parts[0]
            $default = $parts[1]
        }

        switch ($scope.ToLowerInvariant()) {
            'signal' { $dictionary = $Signal }
            'item' { $dictionary = $ItemSignal }
            'plan' { $dictionary = $Plan }
        }

        if ($null -ne $dictionary) {
            $valueSignal = Resolve-PathFromDictionary -Dictionary $dictionary -Path $path -Default $default | Select-Object -Last 1
            if ($opSignal.MergeSignalAndVerifyFailure($valueSignal)) {
                return $opSignal
            }

            $opSignal.SetResult($valueSignal.GetResult())
        }
        else {
            $opSignal.LogWarning("⚠️ Memory variable not found for key: $Path")
        }
    }
    catch {
        $opSignal.LogCritical("🔥 Exception during Invoke-TokenMemory: $_")
    }

    return $opSignal
}
