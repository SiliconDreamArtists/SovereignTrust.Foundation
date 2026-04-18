# =============================================================================
# 🚦 Invoke-JsonTokenCondenser
#  License: MIT License • Copyright (c) 2025 Silicon Dream Artists / BDDB
#  Authors: Shadow PhanTom ☚️🐝🤖/ • Neural Alchemist ⚗️☣️🐲 • Version: 2025.5.22
# =============================================================================
# Invokes Conduction phase processing using a sovereign Graph structure and
# interprets each Phase block in sequence or via branching (OnSuccess / OnFail).
# Compatible with the SDA GridCondenser pipeline and sovereign runtime standards.
# =============================================================================

function Invoke-JsonTokenCondenser {
    [CmdletBinding()]
    param (
        [Signal]$Signal,
        [object]$Plan,
        [Signal]$ItemSignal,
        [string]$RegexPattern = "(?s)\[((?>[^\[\]/]|(?<open>\[)|(?<-open>\]))+(?(open)(?!)))\/\]"
    )

    $opSignal = [Signal]::Start("Invoke-JsonTokenCondenser", $Signal) | Select-Object -Last 1

    $sourceContentPathSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "Path" | Select-Object -Last 1
    if ($opSignal.MergeSignalAndVerifyFailure($sourceContentPathSignal)) { return $opSignal }

    $HydrationStyleSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "HydrationStyle" -SignalLevel "Information" | Select-Object -Last 1
    if ($opSignal.MergeSignalAndVerifyFailure($HydrationStyleSignal)) { return $opSignal }

    $HydrationStyle = $HydrationStyleSignal.HasResult() ? $HydrationStyleSignal.GetResult() : $null
    $resultSignal = Resolve-PathFromDictionary -Dictionary $ItemSignal -Path $sourceContentPathSignal.GetResult() | Select-Object -Last 1
    if ($opSignal.MergeSignalAndVerifyFailure($resultSignal)) { return $opSignal }

    $result = $resultSignal.GetResult()

    if ($HydrationStyle -eq "Deferred") {
        $RegexPattern = "(?s)\[((?>[^\[\]|]|(?<open>\[)|(?<-open>\]))+(?(open)(?!)))\|\]"
    }   

    # Stubbed placeholders for testing
    $MergeCondenserFeedback = $opSignal
    $ReturnRequiredValues = $true

    # Invoke recursive token crawl across the result object

    # TODO: Change this to repeating until it's not making any replacements.
    $_result = Invoke-TokenCrawl -MergeCondenserFeedback $MergeCondenserFeedback `
        -Signal $Signal `
        -ItemSignal $ItemSignal `
        -Plan $Plan `
        -CurrentObject $result `
        -ReturnRequiredValues:$ReturnRequiredValues `
        -RegexPattern $RegexPattern

    # Invoke recursive token crawl across the result object
    $_result = Invoke-TokenCrawl -MergeCondenserFeedback $MergeCondenserFeedback `
        -Signal $Signal `
        -ItemSignal $ItemSignal `
        -Plan $Plan `
        -CurrentObject $result `
        -ReturnRequiredValues:$ReturnRequiredValues `
        -RegexPattern $RegexPattern

    # Invoke recursive token crawl across the result object
    $_result = Invoke-TokenCrawl -MergeCondenserFeedback $MergeCondenserFeedback `
        -Signal $Signal `
        -ItemSignal $ItemSignal `
        -Plan $Plan `
        -CurrentObject $result `
        -ReturnRequiredValues:$ReturnRequiredValues `
        -RegexPattern $RegexPattern

        
    # Invoke recursive token crawl across the result object
    $_result = Invoke-TokenCrawl -MergeCondenserFeedback $MergeCondenserFeedback `
        -Signal $Signal `
        -ItemSignal $ItemSignal `
        -Plan $Plan `
        -CurrentObject $result `
        -ReturnRequiredValues:$ReturnRequiredValues `
        -RegexPattern $RegexPattern

    #-RegexPattern '^@TKN:'
    #"\[([^\[\]=]+?)/\]"

    $opSignal.LogInformation("✅ Token Condenser executed.")
    $opSignal.SetResult($result)
    return $opSignal
}

<# TODO: Fix this not returning an opSignal that is gathering the opSignal results. #>
<# TODO: Invoke-GlobalTokenCrawl is defined twice, it should be genericized for Token #>

function Invoke-TokenCrawl {
    [CmdletBinding()]
    param (
        [Signal]$Signal,
        [object]$Plan,
        [Signal]$ItemSignal,
        [object]$MergeCondenserFeedback,
        [object]$CurrentObject,
        [bool]$ReturnRequiredValues = $true,
        [string]$RegexPattern
    )

    function Invoke-ParseJsonString {
        param ([string]$_input)

        if ([string]::IsNullOrWhiteSpace($_input)) { return $null }

        $trimmed = $_input.Trim()

        try {
            if ($trimmed.StartsWith('Formatter.Json')) {
                return $_input
                return $trimmed | ConvertFrom-Json -ErrorAction Stop
            }

            if ($trimmed.StartsWith('{') -and $trimmed.EndsWith('}')) {
                return $_input
                return $trimmed | ConvertFrom-Json -ErrorAction Stop
            }
            elseif ($trimmed.StartsWith('[') -and $trimmed.EndsWith(']') -and (-not $trimmed.EndsWith('/]') -and -not $trimmed.EndsWith('|]'))) {
                return $_input
                $val = $trimmed | ConvertFrom-Json -ErrorAction Stop
                return @($val)
            }
        }
        catch {
            return $null
        }

        return $_input
    }

    function _ResolveAndDeserializeProperty {
        param (
            [Signal]$Signal,
            [object]$Plan,
            [Signal]$ItemSignal,
            [object]$MergeCondenserFeedback,
            [object]$Parent,
            [string]$Key,
            [bool]$ReturnRequiredValues,
            [string]$RegexPattern,
            [string]$HydrationStyle = ""
        )

        $valueSignal = Resolve-PathFromDictionary -Dictionary $Parent -Path $Key | Select-Object -Last 1
        if ($valueSignal.Failure()) {
            #$MergeCondenserFeedback.LogWarning("Failed to resolve path '$Key' in dictionary '$DictionaryName'.")
            return
        }

        $propObject = [PSCustomObject]@{ Name = $Key; Value = $valueSignal.GetResult() }

        Resolve-TokenForProperty `
            -MergeCondenserFeedback $MergeCondenserFeedback `
            -Property $propObject `
            -Signal $Signal `
            -ItemSignal $ItemSignal `
            -Plan $Plan `
            -HydrationStyle $HydrationStyle `
            -RegexPattern $RegexPattern `
            -ReturnRequiredValues:$ReturnRequiredValues | Select-Object -Last 1 | Out-Null

    if ($HydrationStyle -eq "" -and $propObject.Value -like '*/]*') {
        Resolve-TokenForProperty `
            -MergeCondenserFeedback $MergeCondenserFeedback `
            -Property $propObject `
            -Signal $Signal `
            -ItemSignal $ItemSignal `
            -Plan $Plan `
            -HydrationStyle $HydrationStyle `
            -RegexPattern $RegexPattern `
            -ReturnRequiredValues:$ReturnRequiredValues | Select-Object -Last 1 | Out-Null
        
    }

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
            [Signal]$Signal,
            [object]$Plan,
            [Signal]$ItemSignal,
            [object]$Parent,
            [object]$Key,
            [string]$RegexPattern
        )


        $valueSignal = Resolve-PathFromDictionary -Dictionary $Parent -Path $Key | Select-Object -Last 1
        if ($valueSignal.Failure()) {
            return
        }

        $value = $valueSignal.GetResult()

        if ($null -eq $value) { return }

        if ($value -like "*__*") {
            if ($value -match $RegexPattern) {
                $a = "a"
            }
        }

        switch ($value.GetType().Name) {
            'Hashtable' {
                foreach ($subKey in $value.Keys) {
                    _Walk             -Signal $Signal `
                        -ItemSignal $ItemSignal `
                        -Plan $Plan `
                        -Parent $value -Key $subKey -RegexPattern $RegexPattern
                }
            }
            'PSCustomObject' {
                foreach ($prop in $value.PSObject.Properties) {
                    _Walk             -Signal $Signal `
                        -ItemSignal $ItemSignal `
                        -Plan $Plan `
                        -Parent $value -Key $prop.Name -RegexPattern $RegexPattern
                }
            }
            'Object[]' {
                for ($i = 0; $i -lt $value.Count; $i++) {
                    if ($value[$i] -is [hashtable] -or $value[$i] -is [pscustomobject]) {
                        _Walk             -Signal $Signal `
                            -ItemSignal $ItemSignal `
                            -Plan $Plan `
                            -Parent $value -Key $i -RegexPattern $RegexPattern
                    }
                    elseif ($value[$i] -is [string] -and $value[$i] -match $RegexPattern) {
                        _ResolveAndDeserializeProperty `
                            -Signal $Signal `
                            -ItemSignal $ItemSignal `
                            -Plan $Plan `
                            -MergeCondenserFeedback $MergeCondenserFeedback `
                            -Parent $value `
                            -Key "$i" `
                            -HydrationStyle $HydrationStyle `
                            -ReturnRequiredValues:$ReturnRequiredValues `
                            -RegexPattern $RegexPattern
                    }
                    else {
                        $type = $value[$i].GetType()
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
                        -ItemSignal $ItemSignal `
                        -Plan $Plan `
                        -HydrationStyle $HydrationStyle `
                        -ReturnRequiredValues:$ReturnRequiredValues `
                        -RegexPattern $RegexPattern
                }
            }
        }
    }

    if ($CurrentObject -is [hashtable]) {
        foreach ($key in $CurrentObject.Keys) {
            _Walk             -Signal $Signal `
                -ItemSignal $ItemSignal `
                -Plan $Plan `
                -Parent $CurrentObject -Key $key -RegexPattern $RegexPattern
        }
    }
    elseif ($CurrentObject -is [pscustomobject]) {
        foreach ($prop in $CurrentObject.PSObject.Properties) {
            _Walk             -Signal $Signal `
                -ItemSignal $ItemSignal `
                -Plan $Plan `
                -Parent $CurrentObject -Key $prop.Name -RegexPattern $RegexPattern
        }
    }
    elseif ($CurrentObject -is [array]) {
        foreach ($prop in $CurrentObject) {
            _Walk             -Signal $Signal `
                -ItemSignal $ItemSignal `
                -Plan $Plan `
                -Parent $CurrentObject -Key $prop.Name -RegexPattern $RegexPattern
        }
    }
}
