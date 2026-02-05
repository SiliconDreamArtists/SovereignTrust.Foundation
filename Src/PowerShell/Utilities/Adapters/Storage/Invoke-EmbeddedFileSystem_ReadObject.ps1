function Invoke-EmbeddedFileSystem_ReadObject {
    param (
        [Signal]$Signal,
        [Parameter(Mandatory)][string]$VirtualPath,
        [Parameter()][string]$PathSuffix,
        [Parameter()][object]$Addresses
    )

    $opSignal = [Signal]::Start("Invoke-ReadVirtualFileFromAddresses:$VirtualPath", $Signal) | Select-Object -Last 1

    try {
        # ░▒▓█ NORMALIZE FILE EXTENSION █▓▒░
        if ($PathSuffix -and -not $VirtualPath.ToLower().EndsWith($PathSuffix)) {
            $VirtualPath = "$VirtualPath$PathSuffix"
        }

        foreach ($address in $Addresses) {
            $fullPath = Join-Path -Path $address -ChildPath $VirtualPath

            if (Test-Path -Path $fullPath) {
                $content = Get-Content -Path $fullPath -Raw
                $opSignal.SetResult($content)
                $opSignal.LogInformation("📄 Found and read file: $fullPath")
                return $opSignal
            }
        }

        $opSignal.LogCritical("File '$VirtualPath' not found in any address.")
    }
    catch {
        $opSignal.LogCritical("🔥 Exception during Invoke-ReadVirtualFileFromAddresses: $($_.Exception.Message)", $null, $_)
    }

    return $opSignal
}
