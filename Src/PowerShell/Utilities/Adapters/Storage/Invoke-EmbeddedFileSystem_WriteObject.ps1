function Invoke-EmbeddedFileSystem_WriteObject {
    param (
        [Parameter(Mandatory)][Signal]$Signal,
        [Parameter(Mandatory)][object]$Content,
        [Parameter(Mandatory)][string]$VirtualPath,
        [Parameter()][string]$PathSuffix,
        [Parameter(Mandatory)][object]$Addresses
    )

    $opSignal = [Signal]::Start("Invoke-WriteVirtualFileToAddresses:$VirtualPath", $Signal) | Select-Object -Last 1

    try {
        # ░▒▓█ NORMALIZE FILE EXTENSION █▓▒░
        if ($PathSuffix -and -not $VirtualPath.ToLower().EndsWith($PathSuffix.ToLower())) {
            $VirtualPath = "$VirtualPath$PathSuffix"
        }
        $address = @($Addresses)[0]
        #        foreach ($address in $Addresses) {
        $fullPath = Join-Path -Path $address -ChildPath $VirtualPath

        # Ensure target directory exists
        $dir = Split-Path -Path $fullPath -Parent
        if ($dir -and -not (Test-Path -Path $dir)) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
        }

        if ($Content -is [pscustomobject])
        {
            $Content = $Content | ConvertTo-Json -Depth 100
        }

        # Write content (UTF8, no BOM by default in PS 7)
        Set-Content -Path $fullPath -Value $Content -Encoding utf8 -Force

        $logVirtualPath = $VirtualPath.Replace('\', '/')
        $opSignal.LogInformation("📝 Wrote file: '$logVirtualPath' -> '$fullPath'")
        $opSignal.SetResult($fullPath)
        return $opSignal
        #       }

        $opSignal.LogCritical("No addresses provided to write file '$VirtualPath'.")
    }
    catch {
        $opSignal.LogCritical("🔥 Exception during Invoke-WriteVirtualFileToAddresses: $($_.Exception.Message)", $null, $_)
    }

    return $opSignal
}