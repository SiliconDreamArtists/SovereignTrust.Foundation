# =============================================================================
# 🚦 Invoke-ConductionCondenser
#  License: MIT License • Copyright (c) 2025 Silicon Dream Artists / BDDB
#  Authors: Shadow PhanTom ☚️🐝🤖/ • Neural Alchemist ⚗️☣️🐲 • Version: 2025.5.22
# =============================================================================
# Invokes Conduction phase processing using a sovereign Graph structure and
# interprets each Phase block in sequence or via branching (OnSuccess / OnFail).
# Compatible with the SDA GridCondenser pipeline and sovereign runtime standards.
# =============================================================================

function Invoke-GlobalCondenser {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)] [Signal]$Signal,
        [Parameter(Mandatory)] [object]$Plan,
        [Parameter(Mandatory)] [object]$ItemSignal
    )

    $opSignal = [Signal]::Start("Invoke-GlobalCondenser", $Signal) | Select-Object -Last 1

    $result = $ItemSignal.GetResult()

    # Stubbed placeholders for testing
    $MergeCondenserFeedback = $opSignal
    $Dictionary = $null
    $DictionaryName = "DefaultGlobalDictionary"
    $ReturnRequiredValues = $true

    # Invoke recursive token crawl across the result object
    Invoke-GlobalTokenCrawl -MergeCondenserFeedback $MergeCondenserFeedback `
        -CurrentObject $result `
        -Dictionary $Dictionary `
        -Signal $Signal `
        -DictionaryName $DictionaryName `
        -ReturnRequiredValues:$ReturnRequiredValues

    $opSignal.LogInformation("✅ Global Condenser executed.")

    # HACK - SETTING TO FALSE TO AVOID LOOP, NEEDS TO REVIEW ITSELF FOR CHANGES AND REPORT TRUE/FALSE
    $opSignal.SetResult($false)
    return $opSignal
}

<# TODO: Fix this not returning an opSignal that is gathering the opSignal results. #>

function Invoke-GlobalTokenCrawl {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)] [Signal]$Signal,
        [object]$MergeCondenserFeedback,
        [object]$CurrentObject,
        [object]$Dictionary,
        [string]$DictionaryName,
        [bool]$ReturnRequiredValues = $true
    )

    function _Walk {
        param (
            [object]$Parent,
            [object]$Key
        )
        if ($Key -is [int]) {
            if ($Key -ge 0 -and $Key -lt $Parent.Count) {
                $value = $Parent[$Key]
            }
            else {
                return  # Index out of range, safely exit
            }
        }
        else {
            $valueSignal = Resolve-PathFromDictionary -Dictionary $Parent -Path $Key | Select-Object -Last 1
            if ($valueSignal.Failure()) {
                # $MergeCondenserFeedback.LogWarning("Failed to resolve path '$Key' in dictionary '$DictionaryName'.")
                return
            }

            $value = $valueSignal.GetResult()
        }


        if ($null -eq $value) { return }

        switch ($value.GetType().Name) {
            'Hashtable' {
                foreach ($subKey in $value.Keys) {
                    _Walk -Parent $value -Key $subKey
                }
            }
            'PSCustomObject' {
                foreach ($prop in $value.PSObject.Properties) {
                    _Walk -Parent $value -Key $prop.Name
                }
            }
            'Object[]' {
                for ($i = 0; $i -lt $value.Count; $i++) {
                    if ($value[$i] -is [hashtable] -or $value[$i] -is [pscustomobject]) {
                        _Walk -Parent $value -Key $i
                    }
                    elseif ($value[$i] -is [string]) {
                        if ($value[$i] -match '\[[^@\[]*=[^/]*\/\]') {
                            $propObject = [PSCustomObject]@{ Name = "$i"; Value = $value[$i] }
                            Resolve-GlobalTokenOverrideForProperty -Signal $Signal -MergeCondenserFeedback $MergeCondenserFeedback -Property $propObject -Dictionary $Dictionary -DictionaryName $DictionaryName -SplitMatchCharacter '=' -ReturnRequiredValues:$ReturnRequiredValues | Out-Null
                            $value[$i] = $propObject.Value
                        }
                    }
                }
            }
            'String' {
                if ($value -match '\[[^@\[]*=[^/]*\/\]') {
                    $propObject = [PSCustomObject]@{ Name = $Key; Value = $value }
                    Resolve-GlobalTokenOverrideForProperty -Signal $Signal -MergeCondenserFeedback $MergeCondenserFeedback -Property $propObject -Dictionary $Dictionary -DictionaryName $DictionaryName -SplitMatchCharacter '=' -ReturnRequiredValues:$ReturnRequiredValues | Out-Null
                    Add-PathToDictionary -Dictionary $Parent -Path $Key -Value $propObject.Value | Select-Object -Last 1
                }
            }
        }
    }

    if ($CurrentObject -is [hashtable]) {
        foreach ($key in $CurrentObject.Keys) {
            _Walk -Parent $CurrentObject -Key $key
        }
    }
    elseif ($CurrentObject -is [pscustomobject]) {
        foreach ($prop in $CurrentObject.PSObject.Properties) {
            _Walk -Parent $CurrentObject -Key $prop.Name
        }
    }
}
