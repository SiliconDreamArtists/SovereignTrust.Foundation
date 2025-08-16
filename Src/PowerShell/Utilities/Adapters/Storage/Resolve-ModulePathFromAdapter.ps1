function Resolve-ModulePathFromAdapter {
    [CmdletBinding()]
    param (
        [Signal]$Signal,
        [MappedStorageAdapter]$Adapter,
        [string]$Slot,
        [string]$RelativePath
    )

    $opSignal = [Signal]::Start("Get-ModulePathFromAdapter") | Select-Object -Last 1

    try {
        $root = Resolve-PathFromDictionary -Dictionary $Adapter -Path "$.*.#.$Slot" | Select-Object -Last 1
        if (-not $root.Success()) {
            return $opSignal.MergeSignal($root).LogCritical("❌ Could not resolve root address from adapter.")
        }

        $rootAdapter  = $root.GetResult()

        $rootAdapter = $rootAdapter.GetResult()

        $addressesSignal = Resolve-PathFromDictionary -Dictionary $rootAdapter -Path "%.Addresses" | Select-Object -Last 1
        
        $addresses = $addressesSignal.GetResult()

        foreach ($address in $addresses) {
            $fullPath = Join-Path -Path $address -ChildPath $RelativePath
            if ((Test-Path $fullPath)) {
                $opSignal.SetResult($fullPath)
                $opSignal.LogInformation("📦 Resolved module path: $fullPath")
                break;
            }
        }

        if (-not $opSignal.HasResult()) {
            $opSignal.LogCritical("❌ Could not resolve module path for '$RelativePath' in slot '$Slot'.")
        }
    }
    catch {
        $opSignal.LogCritical("🔥 Exception while resolving module path: $_")
    }

    return $opSignal
}
