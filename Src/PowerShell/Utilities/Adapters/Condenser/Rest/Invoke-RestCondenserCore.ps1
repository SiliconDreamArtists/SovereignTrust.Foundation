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
        "Content-Type" = "application/json"        
    }

    if ($null -eq $Body -and $null -ne $JsonBody) {
        $Body = $JsonBody | ConvertTo-Json -Depth 10
    }

    #$context = Resolve-PathFromDictionary -Dictionary $Config -Path "Context" | Select-Object -Last 1
    $retry = $true
    $clearBearerToken = $false
    $attempts = 0
    $pimChecks = 0
    $maxAttempts = 3
    $maxPimChecks = 10
    $response = $null
    while ($retry) {
        $sw = [System.Diagnostics.Stopwatch]::new() 
        try {
                $QuerystringSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "Querystring" -SignalLevel "Information" | Select-Object -Last 1
                $HeadersSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "Headers" -Default $headers | Select-Object -Last 1
                $UriSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "Uri" | Select-Object -Last 1
                $BearerTokenSignal = Resolve-PathFromDictionary -Dictionary $Plan -Path "BearerToken" | Select-Object -Last 1

$Url = $UriSignal.GetResult()
$Token = $BearerTokenSignal.GetResult()
$Querystring = $QuerystringSignal.GetResult()
$headers = $HeadersSignal.GetResult()

            if ($Token) {
                $headers["Authorization"] = "Bearer $Token"
            }

            $FinalUrl = $Url
            if ($null -ne $Querystring -and $Querystring -ne "" -and $Url -notlike "*$Querystring") {
                $FinalUrl = $Url + $Querystring
            }

            $sw.Start()
            $Method = $Activity
            
            if ($null -ne $Body) {
                if (-not $Method) {
                    $Method = "Post"
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
            <# Remove or fix so it doesn't corrupt the variables
            $TelemetryLevel = "VerboseInformation"
            if ($FinalUrl -like "*applicationinsights*")
            {
                $TelemetryLevel = "Silent"
            }
            Write-TelemetryWrapper -StepConfig $Config -Config @{
                ResourceName         = $ResourceName
                DurationMs           = $sw.ElapsedMilliseconds
                RemoteDependencyName = "$($Method)-RestApi"
                RemoteDependencyType = $Url
                TelemetryLevel       = $TelemetryLevel
                Success              = $true
                TelemetryType      = "Dependency"
                TelemetryDataType  = "RemoteDependencyData"
            }
#>
            #return $response
            $opSignal.SetResult($result)

            return $opSignal
            $retry = $false
        }
        catch {
            if ($sw.IsRunning) { $sw.Stop() }
            $TelemetryLevel = "Critical"
            $attempts++

$headersJson  = ConvertTo-Json -InputObject $headers

            $message = $_.ErrorDetails.Message ?? $_.Exception.Message
            if (    $message -like "*not authorized to perform this operation using this permission*") {
                if ($pimChecks -lt $maxPimChecks) {
                    Write-Host "Check for Role Elevation in PIM, sleeping 30 seconds."
                    $pimChecks++
                    #Start-Sleep -Seconds 30
                    $attempts--
                    $TelemetryLevel = "VerboseCritical"
                }
            }

            if ($message -like "*token is expired*" -or $message -like "*401 (Unauthorized)*" -or $message -like "*authenticate header*") {
                $clearBearerToken = $true
                $Url = $null
            }
            else {
                #Start-Sleep -Milliseconds 10000
            }

            #Clear URL because this call will happen in the same runspace as the current call which has different urls.
            $Url = $null

            & Write-TelemetryWrapper -StepConfig $Config -Config @{
                ResourceName        = $ResourceName
                TelemetryLevel      = $TelemetryLevel
                TelemetryMessage    = $message
                ExceptionType       = $_.CategoryInfo.Reason
                StackTrace          = $_.ScriptStackTrace
                TelemetryType       = "Exception"
                TelemetryDataType   = "ExceptionData"
                TelemetryProperties = @{
                    serviceName = "{(Context.Environment.ServiceName|sonar)}"
                    RequestId   = "$($Config.RequestId)"
                    Method      = "$($Method)"
                    Url         = $FinalUrl
                    Attempt     = $attempts
                    MaxAttempts = $maxAttempts
                }
            }

            $Url = $null
            
            if ($attempts -gt $maxAttempts) {
                $retry = $false
                throw
            }

        }
    } 

}