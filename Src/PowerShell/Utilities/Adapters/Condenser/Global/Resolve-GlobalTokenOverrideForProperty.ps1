<#
─────────────────────────────────────────────────────────────
📌 GLOBAL TOKEN REGEX FORMATS – Reference for $Pattern input
─────────────────────────────────────────────────────────────

[1] Square Bracket Format (Default Style)
Pattern: "\[[^\[@]*=[^\/]*\/\]"
Matches: [key=value/]
Use: Global substitution with key/value embedded in markup.

[2] Curly Bracket Format
Pattern: "\{([a-zA-Z0-9_-]+)\}"
Matches: {key}
Use: Simple key replacement, no template formatting.

[3] Token Prefix Format
Pattern: "@@KEY:([a-zA-Z0-9_.-]+)"
Matches: @@KEY:some.path.value
Use: Recognizes token paths for late-bound replacements.

[4] Named Template Format
Pattern: "\[\[(\w+):([^\]]+)\]\]"
Matches: [[TKN:some.path.here]]
Use: Useful for multi-type prefix tagging.

[5] Custom XPath Style Format
Pattern: "\[([a-zA-Z0-9_]+)=""([^""]+)""\/\]"
Matches: [environmentName="prod"/]
Use: Used for XPath-like dynamic lookups.

─────────────────────────────────────────────────────────────
#>

function Resolve-GlobalTokenOverrideForProperty {
    [CmdletBinding()]
    param (
        [Signal]$Signal,

        [object]$MergeCondenserFeedback,

        [object]$Property,  # A custom object or hashtable with .Name and .Value

        [hashtable]$Dictionary,

        [string]$DictionaryName,

        [bool]$ReturnRequiredValues = $true,

        [string]$RegexPattern = "(?s)\[[^\[@]*=[^\/]*\/\]",

        [string]$HydrationStyle = "",
        [char]$SplitMatchCharacter
    )

    $opSignal = [Signal]::Start("Resolve-GlobalTokenOverrideForProperty:$($Property.Name)", $null) | Select-Object -Last 1

    if ($HydrationStyle -eq "Deferred") {
        $RegexPattern = "(?s)\[[^\[\]\|]*\|\]"

        # Version to get items when they have [] inside the text.
        #$RegexPattern = "\[(.*?)\|\]"
    }

    try {
        $propertyValue = $Property.Value.ToString()
        $pathSegments = $Property.Name -split '\.'

        $Dictionary = @{ }

        $matches = [regex]::Matches($propertyValue, $RegexPattern)

        if ($matches.Count -eq 0) {
            if ($HydrationStyle -eq "Deferred") {
                # Version to get items when they have [] inside the text.
                $RegexPattern = "(?s)\[(.*?)\|\]"
            }

            $matches = [regex]::Matches($propertyValue, $RegexPattern)
        }

                if ($matches.Count -gt 100) {

         $matches = $matches |
                ForEach-Object { $_.Value } |
                Select-Object -Unique
                }
                
        foreach ($match in $matches) {
            $matchText = $match.Value.Trim()
            $equalsIndex = $matchText.Length - 2

            if ($SplitMatchCharacter) {
                $equalsIndex = $matchText.IndexOf($SplitMatchCharacter)
            }

            if ($equalsIndex -le 1) { continue }

            $key = $matchText.Substring(1, $equalsIndex - 1)

            if ($SplitMatchCharacter) {
                $replacementTemplate = $matchText.Substring($equalsIndex + 1, $matchText.Length - ($equalsIndex + 3))
                $lookupSignal = Scan-DictionaryForValue -Dictionary $Dictionary -PathSegments $pathSegments -Key $key | Select-Object -Last 1
            }
            else {

                $adapterSignal = Resolve-PathFromDictionary -Dictionary $Signal -Path "%.*.#.Adapters.*.#.MappedToken.@" | Select-Object -Last 1
                
                $adapter = $adapterSignal.GetResult()

                if ($HydrationStyle -eq "Deferred") {
                    $RegexPattern = "\[[^\[\]\|]*\|\]"
                }

                # Account for line breaks
                if (-not ($RegexPattern -match '^\(\?s\)')) {
                    $RegexPattern = "(?s)$RegexPattern"
                }

                $resultSignal = $adapter.Invoke($key);
                $lookupSignal = [Signal]::Start("Resolve-GlobalTokenOverrideForProperty:$($Property.Name)", $null) | Select-Object -Last 1
                $lookupSignal.SetResult($resultSignal.GetResult())
            }

            $opSignal.MergeSignal($lookupSignal)

            if ($lookupSignal.Success() -and -not [string]::IsNullOrWhiteSpace($lookupSignal.Result)) {

                $replacement = $lookupSignal.Result

                # When a replacement value is a json object, etc, we can't do a replacement and must assume the object is ready to be returned.
                if ($replacement -is [PSCustomObject])
                {
                    $propertyValue = $replacement
                }
                else {
                    if ($SplitMatchCharacter) {
                        $replacement = $replacementTemplate -f $key, $lookupSignal.Result
                    }

                    # Escape the whole key again for regex use
                    $escapedKey = [regex]::Escape($key)  # results in "Formatter\\.FilePath"


                    $RegexPattern = "\[$escapedKey.*?\/\]"
                    if ($HydrationStyle -eq "Deferred") {
                        #\[[^\[\]\|]*\|\]
                        $RegexPattern = "\[$escapedKey.*?\|\]"
                    }

                    $innerRegex = [regex]::new($RegexPattern)
                    
                    $oldValue = $propertyValue

                    $propertyValue = $innerRegex.Replace($propertyValue, $replacement)

                    if ($propertyValue -ne $oldValue) {
                        $opSignal.LogInformation("🔄 Replaced '$key' with '$replacement' in property '$($Property.Name)'")
                    }
                    else {
                      #  $propertyValue = $propertyValue -replace $match.Value, $replacement
                        $opSignal.LogWarning("⚠️ No replacement made for '$key' in property '$($Property.Name)' — token may be malformed or missing. ($propertyValue)")
                    }
                }

            }
        }

        $opSignal.MergeSignal((Add-PathToDictionary -Dictionary $Property -Path "Value" -Value $propertyValue | Select-Object -Last 1))
    }
    catch {
        $opSignal.LogCritical("❌ Exception in global token resolution: $($_.Exception.Message)")
        # $null = $MergeCondenserFeedback.MissingWireGlobalFeedback.Invoke("", "", @())
    }

    return $opSignal
}

function Scan-DictionaryForValue {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [hashtable]$Dictionary,

        [Parameter(Mandatory)]
        [string[]]$PathSegments,

        [Parameter(Mandatory)]
        [string]$Key
    )

    $signal = [Signal]::Start("Scan-DictionaryForValue:$Key", $null) | Select-Object -Last 1

    try {
        $currentDict = $Dictionary
        foreach ($segment in $PathSegments) {
            if ($currentDict.ContainsKey($segment)) {
                $currentDict = $currentDict[$segment]
            }
            else {
                break
            }
        }

        if ($null -ne $currentDict -and $currentDict.ContainsKey($Key)) {
            $signal.SetResult($currentDict[$Key])
        }
        else {
            $signal.SetResult("")
        }
    }
    catch {
        $signal.LogCritical("❌ Failed to extract global '$Key' at path [$($PathSegments -join '.')]: $($_.Exception.Message)")
    }

    return $signal
}
