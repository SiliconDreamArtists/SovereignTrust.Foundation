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

    function Split-DynamicArgs {
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
        if ($expr -notmatch '^(?<fn>[A-Za-z_]\w*)\s*(?:\((?<rawArgs>.*)\))?$') {
            throw "Resolve-DynamicPath: invalid dynamic expression '$Path'"
        }

        $fn = $matches['fn'].ToLowerInvariant()
        $raw = ($matches['rawArgs'] ?? '').Trim()
        $rawArgs = Split-DynamicArgs $raw

        switch ($fn) {

            'null' {
                $opSignal.SetResult($null)
                return $opSignal
            }

            'guid' {
                $opSignal.SetResult([guid]::NewGuid().ToString())
                return $opSignal
            }

            'ToArray' {
                if ($rawArgs.Count -ne 2) {
                    throw "ToArray() requires two arguments. ($rawArgs.Count was supplied)"
                }

                $first = $rawArgs[0]
                $second = $rawArgs[1]
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
            'GetIndex' {
                if ($rawArgs.Count -lt 2) {
                    throw "ToArray() requires at least two arguments. ($($rawArgs.Count) was supplied)"
                }

                # Last item is the index
                $index = [int]$rawArgs[-1]

                # Everything before that is the array
                #$array = @($rawArgs[0..($rawArgs.Count - 2)])

                # Validate index
                if ($index -lt 0 -or $index -ge $rawArgs.Count) {
                    throw "Index $index is out of bounds for array of size $($array.Count)"
                }

                $result = $rawArgs[$index]

                $opSignal.SetResult($result)
                return $opSignal
            }

            'notequals' {
                if ($rawArgs.Count -lt 2) {
                    throw "notequals() requires at least two arguments."
                }

                $first = $rawArgs[0]
                $result = $first -notin $rawArgs[1..($rawArgs.Count - 1)]

                $opSignal.SetResult($result)
                return $opSignal
            }

            'equals' {
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
