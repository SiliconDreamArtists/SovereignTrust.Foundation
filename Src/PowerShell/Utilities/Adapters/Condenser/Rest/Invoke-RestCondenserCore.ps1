function Invoke-RestCondenserCore {
    [CmdletBinding()]
    param (
        [string]$Activity, 
        [string]$Slot,
        # Conduction Signal
        [Parameter(Mandatory)]
        [Signal]$Signal,

        # Phase Set Signal (contains array of Phase ItemSignals or phase objects)
        [Parameter(Mandatory)]
        [Signal]$ItemSignal,

        # Full plan object
        [Parameter(Mandatory)]
        [object]$Plan
    )

    # Build headers based on if there's a body to send.
    $headers = @{
    }

    if ($null -eq $Body -and $null -ne $JsonBody) {
        $Body = $JsonBody | ConvertTo-Json -Depth 10
    }

    #$context = Resolve-PathFromDictionary -Dictionary $Config -Path "Context" | Select-Object -Last 1
    $retry = $true
    $attempts = 0
    $maxAttempts = 2
    $response = $null
    while ($retry) {
        $sw = [System.Diagnostics.Stopwatch]::new() 
        try {
            $QuerystringSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "Config.Querystring" -Default "" -SignalLevel "Information" | Select-Object -Last 1
            $HeadersSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "Config.Headers" -Default $headers | Select-Object -Last 1
            $UriSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "Config.Uri" | Select-Object -Last 1
            $BearerTokenSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "Config.BearerToken" -Default $null | Select-Object -Last 1
            $MethodSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "Config.Method" -Default $null | Select-Object -Last 1

            # TODO: This should be done in ItemSignal instead of Config.Body
            $BodySignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "Config.Body" -Default $null | Select-Object -Last 1

            $Url = $UriSignal.GetResult()
            # Strip Url from array if in an array.
            $Url = (@($Url))[0]

            $Token = $BearerTokenSignal.HasResult() ? $BearerTokenSignal.GetResult() : $null
            $Querystring = $QuerystringSignal.HasResult() ? $QuerystringSignal.GetResult() : $null
            $headers = $HeadersSignal.HasResult() ? $HeadersSignal.GetResult() : $null

            $Body = $BodySignal.HasResult() ? $BodySignal.GetResult() : $null
            $Method = $MethodSignal.HasResult() ? $MethodSignal.GetResult() : $null
            if ($Body -and ($Body -isnot [string])) {
                $Body = $Body | ConvertTo-Json -Depth 100
            }

            if ($headers -is [PSCustomObject])
            {
                $_headers = @{}
                foreach ($property in $headers.PSObject.Properties)
                {
                    $_headers[$property.Name] = $property.Value
                }

                $headers = $_headers
            }

            if ($Token) {
                $headers["Authorization"] = "Bearer $Token"
            }

            $FinalUrl = $Url
            if ($null -ne $Querystring -and $Querystring -ne "" -and $Url -notlike "*$Querystring") {
                $FinalUrl = $Url + $Querystring
            }

            $sw.Start()
            
            if ($null -ne $Body) {
                if (-not $Method) {
                    $Method = "Post"
                }

                # TODO: Do Externally and pass in through config.
            if ($Body) {
                $headers["Content-Type"] = "application/json; charset=utf-8"
                $headers["Accept"] = "application/json"
           }

                $response = Invoke-RestMethod -Uri $FinalUrl -Method $Method -Headers $headers -Body $Body
            }
            else {
                if (-not $Method) {
                    $Method = "get"
                }
                
                $response = Invoke-RestMethod -Uri $FinalUrl -Method $Method -Headers $headers
            }
        
            if ($sw.IsRunning) { $sw.Stop() }

            $opSignal.LogInformation("Rest $Method Successful against $FinalUrl", @("Verbose"))
            $result = @{
                Response            = $Response
                Url                 = $FinalUrl
                Method              = $Method
                ResourceName        = $ResourceName
                Success             = $true
                ElapsedMilliseconds = $sw.ElapsedMilliseconds
            }

            $opSignal.SetResult($result)
            return $opSignal
        }
        catch {
            if ($sw.IsRunning) { $sw.Stop() }
            $attempts++
            $message = $_.ErrorDetails.Message ?? $_.Exception.Message

            # Change this so that this sends the details back to the prior level in the $opSignal to alert it that a failure has happened and this is how you heal it. (ClearBearerToken)
            if ($message -like "*token is expired*" -or $message -like "*401 (Unauthorized)*" -or $message -like "*authenticate header*") {
                #clearBearerToken = $true
            }
            else {
                #Start-Sleep -Milliseconds 10000
            }

            if ($attempts -gt $maxAttempts) {
                $opSignal.LogCritical("Exception during attempt $($attempts) on call to '$FinalUrl' $message", $null, $_)
                return $opSignal
            }

            $opSignal.LogWarning("Attempt $($attempts) Error during call to '$FinalUrl' $message", @("Retry"))
        }
    }
}