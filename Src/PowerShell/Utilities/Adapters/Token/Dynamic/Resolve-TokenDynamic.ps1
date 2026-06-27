function Resolve-TokenDynamic {
    [CmdletBinding()]
    param(
        # Parent signal for lineage
        [Parameter(Mandatory = $false)]
        [Signal]$Signal,

        # Dictionary used by coalesce(...) when it calls Resolve-PathFromDictionary
        [Parameter(Mandatory = $false)]
        [psobject]$Dictionary,

        # Dynamic expression, must start with ::   (e.g. ::utcNow(+1h))
        [Parameter(Mandatory)]
        [string]$Path
    )

    $opSignal = [Signal]::Start("Resolve-TokenDynamic", $Signal) | Select-Object -Last 1
function Convert-LocalDateTimeToUtc {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Date,          # "2024-12-01" or "12/01/2024"

        [Parameter(Mandatory)]
        [string]$LocalTime,     # "17:00:00"

        [Parameter(Mandatory)]
        [string]$TimeZoneId     # "Australia/Lord_Howe"
    )

    $culture = [System.Globalization.CultureInfo]::InvariantCulture

    # Clean inputs
    $cleanDate = ($Date ?? '').Trim().Trim('"', "'")
    $cleanTime = ($LocalTime ?? '').Trim().Trim('"', "'")

    # Normalize whitespace
    $cleanDate = $cleanDate -replace '\s+', ' '
    $cleanTime = $cleanTime -replace '\s+', ' '

    if ([string]::IsNullOrWhiteSpace($cleanDate)) {
        throw "Date is empty."
    }

    if ([string]::IsNullOrWhiteSpace($cleanTime)) {
        throw "LocalTime is empty."
    }

    if ([string]::IsNullOrWhiteSpace($TimeZoneId)) {
        throw "TimeZoneId is empty."
    }

    # Normalize common time input, e.g. "17:00" is allowed.
    $localText = "$cleanDate $cleanTime"
    $localText = $localText.Trim() -replace '\s+', ' '

    $dateFormats = [string[]]@(
        'yyyy-MM-dd HH:mm:ss',
        'yyyy-MM-dd H:mm:ss',
        'yyyy-MM-dd HH:mm',
        'yyyy-MM-dd H:mm',

        'MM/dd/yyyy HH:mm:ss',
        'M/d/yyyy HH:mm:ss',
        'MM/dd/yyyy H:mm:ss',
        'M/d/yyyy H:mm:ss',

        'MM/dd/yyyy HH:mm',
        'M/d/yyyy HH:mm',
        'MM/dd/yyyy H:mm',
        'M/d/yyyy H:mm'
    )

    $localUnspecified = [DateTime]::MinValue

    $parsed = [DateTime]::TryParseExact(
        $localText,
        $dateFormats,
        $culture,
        [System.Globalization.DateTimeStyles]::None,
        [ref]$localUnspecified
    )

    if (-not $parsed) {
        throw "Could not parse local date/time '$localText'. Expected formats like yyyy-MM-dd HH:mm:ss, yyyy-MM-dd HH:mm, MM/dd/yyyy HH:mm:ss, or MM/dd/yyyy HH:mm."
    }

    # This is critical: the parsed value is a wall-clock time in the target timezone.
    $localUnspecified = [DateTime]::SpecifyKind($localUnspecified, [DateTimeKind]::Unspecified)

    try {
        $tz = [System.TimeZoneInfo]::FindSystemTimeZoneById($TimeZoneId)
    }
    catch {
        throw "Could not find timezone '$TimeZoneId'. If you are using Windows PowerShell 5.1, IANA timezone IDs like 'Australia/Lord_Howe' may not work. Use PowerShell 7 or map it to a Windows timezone ID."
    }

    if ($tz.IsInvalidTime($localUnspecified)) {
        throw "The local time '$localText' is invalid in timezone '$TimeZoneId' because of a daylight-saving transition."
    }

    $isAmbiguous = $tz.IsAmbiguousTime($localUnspecified)
    if ($isAmbiguous) {
        Write-Warning "The local time '$localText' is ambiguous in timezone '$TimeZoneId' because of a daylight-saving transition."
    }

    $utcDateTime = [System.TimeZoneInfo]::ConvertTimeToUtc($localUnspecified, $tz)
    $utcOffset = $tz.GetUtcOffset($localUnspecified)

    $utcDateTimeOffset = [DateTimeOffset]::new(
        [DateTime]::SpecifyKind($utcDateTime, [DateTimeKind]::Utc)
    )

    $epochUtc = $utcDateTimeOffset.ToUnixTimeSeconds()

    return [pscustomobject]@{
        Date                  = $localUnspecified.ToString('yyyy-MM-dd', $culture)
        LocalTime             = $localUnspecified.ToString('HH:mm:ss', $culture)
        DisplayTime           = $localUnspecified.ToString('h:mm tt', $culture)
        Timezone              = $TimeZoneId
        UtcOffset             = $utcOffset.ToString()
        UtcDateTime           = $utcDateTime.ToString("yyyy-MM-ddTHH:mm:ssZ", $culture)
        DatetimeEpochUtc      = $epochUtc
        IsAmbiguousLocalTime  = $isAmbiguous
    }
}
    function Convert-To12HourTime {
        param([string]$TimeText)

        if ([string]::IsNullOrWhiteSpace($TimeText)) {
            return $null
        }

        $cleanTime = $TimeText.Trim().Trim('"', "'")

        $formats = [string[]]@(
            'HH:mm:ss',
            'H:mm:ss',
            'HH:mm',
            'H:mm'
        )

        $culture = [System.Globalization.CultureInfo]::InvariantCulture
        $styles = [System.Globalization.DateTimeStyles]::None
        $dt = [DateTime]::MinValue

        if (-not [DateTime]::TryParseExact($cleanTime, $formats, $culture, $styles, [ref]$dt)) {
            throw "get12hourtime() could not parse time '$TimeText'. Cleaned value was '$cleanTime'. Expected HH:mm:ss, H:mm:ss, HH:mm, or H:mm."
        }

        return $dt.ToString('h:mm tt', $culture)
    }

    function Split-DynamicArgs {
        param([string]$Text)

        if ($null -eq $Text -or $Text.Length -eq 0) { return @() }

        $parts = @()
        $sb = [System.Text.StringBuilder]::new()
        $inS = $false
        $inD = $false

        foreach ($ch in $Text.ToCharArray()) {
            switch ($ch) {
                "'" {
                    if (-not $inD) { $inS = -not $inS }
                    [void]$sb.Append($ch)
                }

                '"' {
                    if (-not $inS) { $inD = -not $inD }
                    [void]$sb.Append($ch)
                }

                ',' {
                    if ($inS -or $inD) {
                        [void]$sb.Append($ch)
                    }
                    else {
                        $parts += $sb.ToString()
                        [void]$sb.Clear()
                    }
                }

                default {
                    [void]$sb.Append($ch)
                }
            }
        }

        # Add final argument, even if empty
        $parts += $sb.ToString()

        return $parts | ForEach-Object {
            $raw = $_

            # Trim only enough to detect whether the whole value is quoted.
            # This allows: abc, ' value ' ,+
            $check = $raw.Trim()

            if ($check.Length -ge 2 -and
                (
                    ($check.StartsWith("'") -and $check.EndsWith("'")) -or
                    ($check.StartsWith('"') -and $check.EndsWith('"'))
                )) {
                # Quoted value: remove wrapping quotes, but do NOT trim inside
                $quoteChar = $check.Substring(0, 1)

                # Find the quoted content from the trimmed wrapper
                $s = $check.Substring(1, $check.Length - 2)

                return $s
            }
            else {
                # Unquoted value: normal trim
                return $raw.Trim()
            }
        }
    }
    function Split-DynamicArgs-previous {
        param([string]$Text)
        if ([string]::IsNullOrWhiteSpace($Text)) { return @() }

        $parts = @()
        $sb = [System.Text.StringBuilder]::new()
        $inS = $false; $inD = $false

        foreach ($ch in $Text.ToCharArray()) {
            switch ($ch) {
                "'" { if (-not $inD) { $inS = -not $inS }; [void]$sb.Append($ch) }
                '"' { if (-not $inS) { $inD = -not $inD }; [void]$sb.Append($ch) }
                ',' {
                    if ($inS -or $inD) { [void]$sb.Append($ch) }
                    else { $parts += $sb.ToString().Trim(); [void]$sb.Clear() }
                }
                default { [void]$sb.Append($ch) }
            }
        }
        if ($sb.Length -gt 0) { $parts += $sb.ToString().Trim() }

        # Strip one layer of wrapping quotes
        return $parts | ForEach-Object {
            $s = $_
            if ($s.Length -ge 2 -and
                (( $s.StartsWith("'") -and $s.EndsWith("'")) -or ( $s.StartsWith('"') -and $s.EndsWith('"')))) {
                $s = $s.Substring(1, $s.Length - 2)
            }
            $s
        }
    }

    function Invoke-ParseOffset {
        param([string]$Text, $rawArgs)

        if ([string]::IsNullOrWhiteSpace($Text)) { return [TimeSpan]::Zero }

        $t = $Text.Trim()
        $sgn = 1
        if ($t.StartsWith('+')) { $t = $t.Substring(1) }
        elseif ($t.StartsWith('-')) { $sgn = -1; $t = $t.Substring(1) }

        $m = [regex]::Matches($t, '(\d+)([smhdw])', 'IgnoreCase')
        if ($m.Count -eq 0) {
            throw "Resolve-DynamicPath: invalid offset '$Text'; use +7d, -2h, +90m, +1w, +1h30m, etc."
        }

        $total = [TimeSpan]::Zero
        foreach ($g in $m) {
            $n = [int]$g.Groups[1].Value
            switch ($g.Groups[2].Value.ToLowerInvariant()) {
                's' { $total += [TimeSpan]::FromSeconds($n) }
                'm' { $total += [TimeSpan]::FromMinutes($n) }
                'h' { $total += [TimeSpan]::FromHours($n) }
                'd' { $total += [TimeSpan]::FromDays($n) }
                'w' { $total += [TimeSpan]::FromDays(7 * $n) }
            }
        }

        if ($sgn -lt 0) { $total = - $total }
        return $total
    }

    try {
        # 2) Extract expression after ::
        $expr = ($Path -replace '^\s*::', '').Trim()

        # 4) Parse dynamic function: name(args...)
        #        if ($expr -notmatch '^(?<fn>[A-Za-z_]\w*)\s*(?:\((?<rawArgs>.*)\))?$') {
        #            throw "Resolve-DynamicPath: invalid dynamic expression '$Path'"
        #        }

        # Line Break Safe
        if ($expr -notmatch '^(?<fn>[A-Za-z_]\w*)\s*(?:\((?s)(?<rawArgs>.*)\))?$') {
            throw "Resolve-DynamicPath: invalid dynamic expression '$Path'"
        }

        $fn = $matches['fn'].ToLowerInvariant()
        $raw = ($matches['rawArgs'] ?? '').Trim()
        $rawArgs = Split-DynamicArgs $raw

        switch ($fn) {
            'replace' {
                $matchValueIndex = $rawArgs.Count - 2
                $replaceValueIndex = $rawArgs.Count - 1

                $matchValue = $rawArgs[$matchValueIndex]
                $replaceValue = $rawArgs[$replaceValueIndex]

                # Everything before match/replace is the source value
                $valueArgs = @($rawArgs[0..($rawArgs.Count - 3)])
                $value = ($valueArgs -join ',')

                # Replace matchValue with replaceValue
                $finalValue = $value -replace [regex]::Escape($matchValue), $replaceValue
                $opSignal.SetResult($finalValue)
                return $opSignal
            }

            'null' {
                $opSignal.SetResult($null)
                return $opSignal
            }

            'guid' {
                $opSignal.SetResult([guid]::NewGuid().ToString())
                return $opSignal
            }

            'gt' {
                if ($rawArgs.Count -ne 2) {
                    throw "GreaterThan() requires two arguments. ($rawArgs.Count was supplied)"
                }

                $result = [int]$rawArgs[0] -gt [int]$rawArgs[1]

                $opSignal.SetResult($result)
                return $opSignal
            }

            'lt' {
                if ($rawArgs.Count -ne 2) {
                    throw "LesserThan() requires two arguments. ($rawArgs.Count was supplied)"
                }

                $result = [int]$rawArgs[0] -lt [int]$rawArgs[1]

                $opSignal.SetResult($result)
                return $opSignal
            }

            'add' {
                if ($rawArgs.Count -ne 2) {
                    throw "Add() requires two arguments. ($rawArgs.Count was supplied)"
                }

                $result = [int]$rawArgs[0] + [int]$rawArgs[1]

                $opSignal.SetResult($result)
                return $opSignal
            }

            'subtract' {
                if ($rawArgs.Count -ne 2) {
                    throw "Subtract() requires two arguments. ($rawArgs.Count was supplied)"
                }

                $result = [int]$rawArgs[0] - [int]$rawArgs[1]

                $opSignal.SetResult($result)
                return $opSignal
            }

            'toarray' {
                if ($rawArgs.Count -lt 2) {
                    throw "ToArray() requires two arguments. ($($rawArgs.Count) was supplied)"
                }

                $first = $rawArgs[0]
                $second = $rawArgs[-1]
                $result = $first -split ('\' + $second)

                $opSignal.SetResult($result)
                return $opSignal
            }

            'substring' {
                if ($rawArgs.Count -lt 1) {
                    throw "substring() requires at least one argument (length). ($($rawArgs.Count) supplied)"
                }

                # Length comes from the LAST argument
                $length = [int]$rawArgs[-1]

                if ($null -eq $raw) {
                    throw "substring() requires `$raw to be defined."
                }

                if ($length -lt 0) {
                    throw "substring() length must be >= 0. ($length supplied)"
                }

                if ($length -gt $raw.Length) {
                    $length = $raw.Length
                }

                $result = $raw.Substring(0, $length)

                $opSignal.SetResult($result)
                return $opSignal
            }

            'getindex' {
                if ($rawArgs.Count -lt 2) {
                    throw "GetIndex requires at least two arguments. ($($rawArgs.Count) was supplied)"
                }

                # Last item is the requested index
                $index = [int]$rawArgs[-1]

                # Everything before that is the array to index into
                $array = @($rawArgs[0..($rawArgs.Count - 2)])

                # Convert negative index to reverse lookup
                # -1 = last item, -2 = second-to-last, etc.
                if ($index -lt 0) {
                    $index = $array.Count + $index
                }

                # Validate index after conversion
                if ($index -lt 0 -or $index -ge $array.Count) {
                    $opSignal.LogWarning("Index $index is out of bounds for array of size $($array.Count)")
                    $result = $null
                }
                else {
                    $result = $array[$index]
                }

                $opSignal.SetResult($result)
                return $opSignal
            }

            'toint' {

                $value = $rawArgs[0]

                $result = [int]$value

                $opSignal.SetResult($result)
                return $opSignal
            }

            'tojson' {
                #tbd
                if ($rawArgs.Count -lt 2) {
                    throw "ToArray() requires at least two arguments. ($($rawArgs.Count) was supplied)"
                }

                # Last item is the index
                $delimeter = $rawArgs[-1]

                $json = ($rawArgs[0..($rawArgs.Count - 2)]) -join ','

                #$json_object = $json | ConvertTo-Json -Depth 10
                $json_object = $json | ConvertFrom-Json -Depth 10

                $values = @()

                foreach ($property in $json_object.PSObject.Properties) {
                    $values += $property.Value
                }

                $result = $values -join $delimeter

                $opSignal.SetResult($result)
                return $opSignal
            }

            'fromjson' {
                #tbd
                # Last item is the index
                $delimeter = $rawArgs[-1]

                $json = ($rawArgs[0..($rawArgs.Count - 2)]) -join ','

                $json_object = $json | ConvertTo-Json -Depth 10
                #$json_object = $json | ConvertFrom-Json -Depth 10

                $values = @()

                foreach ($property in $json_object.PSObject.Properties) {
                    $values += $property.Value
                }

                $result = $values -join $delimeter

                $opSignal.SetResult($result)
                return $opSignal
            }

            'join' {
                # Joins a single array into a string
                if ($rawArgs.Count -lt 2) {
                    throw "Join() requires at least two arguments: a JSON array and a delimiter. ($($rawArgs.Count) was supplied)"
                }

                # Last item is the delimiter
                $delimiter = $rawArgs[-1]

                # Everything before the delimiter is JSON
                # This allows the JSON array itself to contain commas
                $json = ($rawArgs[0..($rawArgs.Count - 2)]) -join ','

                $jsonObject = $json | ConvertFrom-Json -Depth 10

                # Join the single array using the delimiter
                $result = @($jsonObject) -join $delimiter

                $opSignal.SetResult($result)
                return $opSignal
            }

            'joinvalues' {
                # Joins from Json Objects
                if ($rawArgs.Count -lt 2) {
                    throw "ToArray() requires at least two arguments. ($($rawArgs.Count) was supplied)"
                }

                # Last item is the index
                $delimeter = $rawArgs[-1]

                $json = ($rawArgs[0..($rawArgs.Count - 2)]) -join ','

                $json_object = $json | ConvertFrom-Json -Depth 10

                $values = @()

                foreach ($property in $json_object.PSObject.Properties) {
                    $values += $property.Value
                }

                $result = $values -join $delimeter

                $opSignal.SetResult($result)
                return $opSignal
            }

            'joinarrays' {
                # Joins a matrix of arrays
                if ($rawArgs.Count -lt 2) {
                    throw "ToArray() requires at least two arguments. ($($rawArgs.Count) was supplied)"
                }

                # Last item is the delimiter
                $delimiter = $rawArgs[-1]

                # Everything before the delimiter is JSON
                $json = ($rawArgs[0..($rawArgs.Count - 2)]) -join ','
                $jsonObject = $json | ConvertFrom-Json -Depth 10

                $values = @()

                foreach ($inner in $jsonObject) {
                    # Join each inner array with nothing
                    $values += ($inner -join '')
                }

                # Join all results with the delimiter
                $result = $values -join $delimiter

                $opSignal.SetResult($result)
                return $opSignal
            }

            'notequals' {
                if ($rawArgs.Count -lt 2) {
                    throw "notequals() requires at least two arguments."
                }

                $first = $rawArgs[0]
                $result = $first -ne $rawArgs[($rawArgs.Count - 1)]

                $opSignal.SetResult($result)
                return $opSignal
            }

            'equals' {
                if ($rawArgs.Count -lt 2) {
                    throw "equals() requires at least two arguments."
                }

                $first = $rawArgs[0]
                $result = $first -eq $rawArgs[($rawArgs.Count - 1)]

                $opSignal.SetResult($result)
                return $opSignal
            }

            'notin' {
                if ($rawArgs.Count -lt 2) {
                    throw "notequals() requires at least two arguments."
                }

                $first = $rawArgs[0]
                $result = $first -notin $rawArgs[1..($rawArgs.Count - 1)]

                $opSignal.SetResult($result)
                return $opSignal
            }

            'in' {
                if ($rawArgs.Count -lt 2) {
                    throw "equals() requires at least two arguments."
                }

                $first = $rawArgs[0]
                $result = $first -in $rawArgs[1..($rawArgs.Count - 1)]

                $opSignal.SetResult($result)
                return $opSignal
            }

            'and' {
                $result = ($null -ne $rawArgs) -and ($rawArgs.Count -gt 0) -and `
                ($rawArgs | ForEach-Object { $_.ToString().ToLower() -eq "true" } | Where-Object { -not $_ } | Measure-Object).Count -eq 0

                $opSignal.SetResult($result)
                return $opSignal

            }

            'or' {
                $result = ($null -ne $rawArgs) -and ($rawArgs.Count -gt 0) -and `
                ($rawArgs | ForEach-Object { $_.ToString().ToLower() -eq "true" } | Where-Object { $_ } | Measure-Object).Count -gt 0

                $opSignal.SetResult($result)
                return $opSignal
            }

            'isnull' {
                $result = $null -eq $rawArgs
                $opSignal.SetResult($result)
                return $opSignal
            }

            'isnotnull' {
                $result = $null -ne $rawArgs
                $opSignal.SetResult($result)
                return $opSignal
            }

            'newguid' {
                $opSignal.SetResult([guid]::NewGuid().ToString())
                return $opSignal
            }

            'utcnow' {
                # Kusto datetime best practice: UTC ISO 8601 round-trip string ("o") with Z suffix
                # utcNow([offset])
                $offset = [TimeSpan]::Zero
                if ($rawArgs.Count -ge 1 -and -not [string]::IsNullOrWhiteSpace($rawArgs[0])) {
                    $offset = Invoke-ParseOffset $rawArgs $rawArgs
                }

                $dt = [DateTime]::UtcNow + $offset
                $dtUtc = [DateTime]::SpecifyKind($dt, [DateTimeKind]::Utc)

                $opSignal.SetResult($dtUtc.ToString('o', [System.Globalization.CultureInfo]::InvariantCulture))
                return $opSignal
            }

            'get12hourtime' {
                if ($rawArgs.Count -ne 1) {
                    throw "get12hourtime() requires one argument. ($($rawArgs.Count) was supplied)"
                }

                $result = Convert-To12HourTime $rawArgs

                $opSignal.SetResult($result)
                return $opSignal
            }

            'localtoutc' {
                if ($rawArgs.Count -ne 3) {
                    throw "get12hourtime() requires 3 arguments. ($($rawArgs.Count) was supplied)"
                }

                $result = Convert-LocalDateTimeToUtc -Date $rawArgs[0] -LocalTime $rawArgs[1] -TimeZoneId $rawArgs[2]

                $opSignal.SetResult($result.UtcDateTime)
                return $opSignal
            }

            default {
                throw "Resolve-DynamicPath: unknown function '$fn' in '$Path'."
            }
        }
    }
    catch {
        $opSignal.LogCritical("🔥 Exception during Resolve-DynamicPath ($Path): $_", $null, $_)
    }

    return $opSignal
}
