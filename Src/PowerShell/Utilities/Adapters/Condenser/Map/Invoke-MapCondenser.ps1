function Invoke-MapCondenser {
    [CmdletBinding()]
    param (
        [Signal]$Signal,
        [object]$Proposal,
        [object]$Context = $null
    )

    $opSignal = [Signal]::Start("Invoke-MapCondenser", $Signal) | Select-Object -Last 1

    if (-not $Proposal) {
        $opSignal.LogCritical("❌ Missing Proposal object.")
        return $opSignal
    }

    $mode = $Proposal.CondenserMode
    if ([string]::IsNullOrWhiteSpace($mode)) {
        $mode = 'Direct'
        $opSignal.LogVerbose("ℹ️ Defaulting CondenserMode to 'Direct'.")
    }

    switch ($mode) {
        'Direct' {
            $directResult = Invoke-DirectMapCondenser -Proposal $Proposal
            $opSignal.MergeSignal($directResult)
            return $opSignal
        }

        'Template' {
            $templateResult = Invoke-TemplateMapCondenser -Signal $opSignal -Proposal $Proposal -Context $Context
            return $templateResult
        }

        default {
            $opSignal.LogCritical("❌ Unknown CondenserMode: $mode")
            return $opSignal
        }
    }
}
