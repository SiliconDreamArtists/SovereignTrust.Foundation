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
    $maxAttempts = 3
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
            $Token = $BearerTokenSignal.HasResult() ? $BearerTokenSignal.GetResult() : $null
            $Querystring = $QuerystringSignal.HasResult() ? $QuerystringSignal.GetResult() : $null
            $headers = $HeadersSignal.HasResult() ? $HeadersSignal.GetResult() : $null

            $Body = $BodySignal.HasResult() ? $BodySignal.GetResult() : $null
            $Method = $MethodSignal.HasResult() ? $MethodSignal.GetResult() : $null
            if ($Body -and -not $Body -is [string]) {
                $Body = $Body | ConvertTo-Json -Depth 100
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
            $TelemetryLevel = "Critical"
            $attempts++

            $message = $_.ErrorDetails.Message ?? $_.Exception.Message

            # Change this so that this sends the details back to the prior level in the $opSignal to alert it that a failure has happened and this is how you heal it. (ClearBearerToken)
            if ($message -like "*token is expired*" -or $message -like "*401 (Unauthorized)*" -or $message -like "*authenticate header*") {
                #clearBearerToken = $true
            }
            else {
                #Start-Sleep -Milliseconds 10000
            }

            $TelemetrySignal = [Signal]::Start("Exception") | Select-Object -Last 1
            $TelemetryResult = @{
                ResourceName        = $ResourceName
                TelemetryLevel      = $TelemetryLevel
                TelemetryMessage    = $message
                ExceptionType       = $_.CategoryInfo.Reason
                StackTrace          = $_.ScriptStackTrace
                TelemetryType       = "Exception"
                TelemetryDataType   = "ExceptionData"
                TelemetryProperties = @{
                    serviceName = "[Memory.Signal.%.@.ServiceName|SDAFusion/]"
                    Method      = "$($Method)"
                    Url         = $FinalUrl
                    Attempt     = $attempts
                    MaxAttempts = $maxAttempts
                }
            }

            $TelemetrySignal.SetJacketResult($TelemetryResult) | Select-Object -Last 1

            # Call Adapter
            Invoke-MappedAdapter -Adapter "Network.Telemetry" -Activity "Emit" -Signal $Signal -Plan $TelemetryPlan -ItemSignal $TelemetrySignal 

            if ($attempts -gt $maxAttempts) {
                $retry = $false
                throw
            }

        }
    } 

}