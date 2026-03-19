$root = "$PSScriptRoot"
if ($root -ne (Get-Location).Path) {
    Set-Location $root
}

New-ModuleManifest -Path ./SovereignTrust.Foundation.psd1 `
  -RootModule 'SovereignTrust.Foundation.psm1' `
  -ModuleVersion '1.0.0' `
  -Author 'Silicon Dream Artists' `
  -CompanyName 'Silicon Dream Artists' `
  -Description 'Native PowerShell implementation for the core components for SovereignTrust.' `
  -Tags "'SovereignTrust.Foundation' 'SovereignTrust' 'Public' 'Core'" `
  -LicenseUri 'https://opensource.org/licenses/MIT' `
  -ProjectUri 'https://github.com/SiliconDreamArtists/SovereignTrust.Foundation' `
  -CompatiblePSEditions 'Core' `
  -PowerShellVersion '5.1'

  Invoke-GenerateModuleFile -OutputFile 'SovereignTrust.Foundation.psm1' -Root $PSScriptRoot
  

  