# Load Direct and Template Map Condenser functions
. "$PSScriptRoot/Invoke-DirectMapCondenser.ps1"
. "$PSScriptRoot/Invoke-TemplateMapCondenser.ps1"
. "$PSScriptRoot/Invoke-MapCondenser.ps1"

function Get-MapCondenserVariableTags {
    param (
        [string]$Content,
        [string]$Type
    )
    if (-not $Content) { return @() }

    switch ($Type) {
        'AtAttag'     { return [regex]::Matches($Content, "@@[a-zA-Z0-9-]+") | ForEach-Object { $_.Value.Substring(2) } }
        'HashHashtag' { return [regex]::Matches($Content, "##[a-zA-Z0-9_.-]+") | ForEach-Object { $_.Value.Substring(2) } }
        default       { return @() }
    }
}

function Get-MapCondenserReplacementPatterns {
    param (
        [string]$Tag,
        [string]$Type
    )

    switch ($Type) {
        'XmlTag'       { return @("<$Tag />", "&lt;$Tag /&gt;") }
        'HashHashtag'  { return @("##$Tag") }
        'AtAttag'      { return @("@@$Tag") }
        default        { return @() }
    }
}

function Replace-MapCondenserTags {
    param (
        [string]$Input,
        [string]$Value,
        [string]$Tag,
        [string]$MappingType,
        [string]$ReplacementType
    )

    if ($MappingType -eq 'Set') {
        return $Value
    }

    $patterns = Get-MapCondenserReplacementPatterns -Tag $Tag -Type $ReplacementType
    foreach ($pattern in $patterns) {
        $Input = $Input.Replace($pattern, $Value)
    }

    return $Input
}


Export-ModuleMember -Function Invoke-DirectMapCondenser, Invoke-TemplateMapCondenser, Invoke-MapCondenser
