# =============================================================================
# 🚦 Invoke-TokenCondenser
#  License: MIT License • Copyright (c) 2025 Silicon Dream Artists / BDDB
#  Authors: Shadow PhanTom ☚️🐝🤖/ • Neural Alchemist ⚗️☣️🐲 • Version: 2025.5.22
# =============================================================================
# Invokes Conduction phase processing using a sovereign Graph structure and
# interprets each Phase block in sequence or via branching (OnSuccess / OnFail).
# Compatible with the SDA GridCondenser pipeline and sovereign runtime standards.
# =============================================================================

function Invoke-TokenCondenser {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)] [Signal]$Signal,
        [Parameter(Mandatory)] [object]$Plan,
        [Parameter(Mandatory)] [object]$ItemSignal
    )

    $opSignal = [Signal]::Start("Invoke-TokenCondenser", $Signal) | Select-Object -Last 1

    $result = $ItemSignal.GetResult()

    # Stubbed placeholders for testing
    $MergeCondenserFeedback = $opSignal
    $Dictionary = $null
    $DictionaryName = "DefaultGlobalDictionary"
    $ReturnRequiredValues = $true

    $RegexPattern = "\[[^\[@=]*=[^\/]*\/\]|\[[^\]]+\/\]"
    $RegexPattern = "\[([^\[\]=]+?)/\]"
    $RegexPattern = "\[((?>[^\[\]/]|(?<open>\[)|(?<-open>\]))+(?(open)(?!)))\/\]"

    $RegexPattern = "\[((?>[^\[\]/]|(?<open>\[)|(?<-open>\]))+(?(open)(?!)))\/\]"

    # Invoke recursive token crawl across the result object
    $_result = Invoke-TokenCrawl -MergeCondenserFeedback $MergeCondenserFeedback `
        -CurrentObject $result `
        -Dictionary $Dictionary `
        -DictionaryName $DictionaryName `
        -ReturnRequiredValues:$ReturnRequiredValues `
        -RegexPattern $RegexPattern

    $RegexPattern = "\[([^\[\]/]+)\/\]"

    # Use this for basic [Token.Path/] forms
    $RegexPattern = "\[((?>[^\[\]/]|(?<open>\[)|(?<-open>\]))+(?(open)(?!)))\/\]"

    # Invoke recursive token crawl across the result object
    $_result = Invoke-TokenCrawl -MergeCondenserFeedback $MergeCondenserFeedback `
        -CurrentObject $result `
        -Dictionary $Dictionary `
        -DictionaryName $DictionaryName `
        -ReturnRequiredValues:$ReturnRequiredValues `
        -RegexPattern $RegexPattern

    #-RegexPattern '^@TKN:'
    #"\[([^\[\]=]+?)/\]"

    $opSignal.LogInformation("✅ Global Condenser executed.")
    return $opSignal
}

<# TODO: Fix this not returning an opSignal that is gathering the opSignal results. #>
<# TODO: Invoke-GlobalTokenCrawl is defined twice, it should be genericized for Token #>

function Invoke-TokenCrawl {
    [CmdletBinding()]
    param (
        [object]$MergeCondenserFeedback,
        [object]$CurrentObject,
        [object]$Dictionary,
        [string]$DictionaryName,
        [bool]$ReturnRequiredValues = $true,
        [string]$RegexPattern
    )

    function Invoke-ParseJsonString {
        param ([string]$_input)

        if ([string]::IsNullOrWhiteSpace($_input)) { return $null }

        $trimmed = $_input.Trim()

        try {
            if ($trimmed.StartsWith('{') -and $trimmed.EndsWith('}')) {
                return $trimmed | ConvertFrom-Json -ErrorAction Stop
            }
            elseif ($trimmed.StartsWith('[') -and $trimmed.EndsWith(']') -and -not $trimmed.EndsWith('/]')) {
                return @($trimmed | ConvertFrom-Json -ErrorAction Stop)
            }
        }
        catch {
            return $null
        }

        return $_input
    }

    function _ResolveAndDeserializeProperty {
        param (
            [Parameter(Mandatory)] [Signal]$Signal,
            [object]$MergeCondenserFeedback,
            [object]$Parent,
            [string]$Key,
            [object]$Dictionary,
            [string]$DictionaryName,
            [bool]$ReturnRequiredValues,
            [string]$RegexPattern
        )

        $valueSignal = Resolve-PathFromDictionary -Dictionary $Parent -Path $Key | Select-Object -Last 1
        if ($valueSignal.Failure()) {
            #$MergeCondenserFeedback.LogWarning("Failed to resolve path '$Key' in dictionary '$DictionaryName'.")
            return
        }

        if ($Key -eq "1")
        {
$x = $valueSignal
        }

        $propObject = [PSCustomObject]@{ Name = $Key; Value = $valueSignal.GetResult() }

        Resolve-GlobalTokenOverrideForProperty `
            -MergeCondenserFeedback $MergeCondenserFeedback `
            -Property $propObject `
            -Signal $Signal `
            -Dictionary $Dictionary `
            -DictionaryName $DictionaryName `
            -RegexPattern $RegexPattern `
            -ReturnRequiredValues:$ReturnRequiredValues | Select-Object -Last 1 | Out-Null

        $propertyValue = $propObject.Value

        if ($propertyValue -is [string] -and $null -ne $propertyValue) {
            $parsed = Invoke-ParseJsonString -_input $propertyValue
            if ($null -ne $parsed) {
                $propertyValue = $parsed
            }
        }

        Add-PathToDictionary -Dictionary $Parent -Path $Key -Value $propertyValue | Select-Object -Last 1 | Out-Null
    }

    function _Walk {
        param (
            [object]$Parent,
            [string]$Key,
            [string]$RegexPattern
        )

        $valueSignal = Resolve-PathFromDictionary -Dictionary $Parent -Path $Key | Select-Object -Last 1
        if ($valueSignal.Failure()) {
            return
        }

        $value = $valueSignal.GetResult()

        if ($null -eq $value) { return }

        switch ($value.GetType().Name) {
            'Hashtable' {
                foreach ($subKey in $value.Keys) {
                    _Walk -Parent $value -Key $subKey -RegexPattern $RegexPattern
                }
            }
            'PSCustomObject' {
                foreach ($prop in $value.PSObject.Properties) {
                    _Walk -Parent $value -Key $prop.Name -RegexPattern $RegexPattern
                }
            }
            'Object[]' {
                for ($i = 0; $i -lt $value.Count; $i++) {
                    if ($value[$i] -is [hashtable] -or $value[$i] -is [pscustomobject]) {
                        _Walk -Parent $value -Key $i -RegexPattern $RegexPattern
                    }
                    elseif ($value[$i] -is [string] -and $value[$i] -match $RegexPattern) {
                        _ResolveAndDeserializeProperty `
                            -MergeCondenserFeedback $MergeCondenserFeedback `
                            -Parent $value `
                            -Key "$i" `
                            -Signal $Signal `
                            -Dictionary $Dictionary `
                            -DictionaryName $DictionaryName `
                            -ReturnRequiredValues:$ReturnRequiredValues `
                            -RegexPattern $RegexPattern
                    }
                }
            }
            'String' {
                if ($value -match $RegexPattern) {
                    _ResolveAndDeserializeProperty `
                        -MergeCondenserFeedback $MergeCondenserFeedback `
                        -Parent $Parent `
                        -Key $Key `
                        -Signal $Signal `
                        -Dictionary $Dictionary `
                        -DictionaryName $DictionaryName `
                        -ReturnRequiredValues:$ReturnRequiredValues `
                        -RegexPattern $RegexPattern
                }
            }
        }
    }

    if ($CurrentObject -is [hashtable]) {
        foreach ($key in $CurrentObject.Keys) {
            _Walk -Parent $CurrentObject -Key $key -RegexPattern $RegexPattern
        }
    }
    elseif ($CurrentObject -is [pscustomobject]) {
        foreach ($prop in $CurrentObject.PSObject.Properties) {
            _Walk -Parent $CurrentObject -Key $prop.Name -RegexPattern $RegexPattern
        }
    }
}
