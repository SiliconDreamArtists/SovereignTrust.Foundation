class GlobalCondenser {
    [object]$MappedCondenserAdapter
    [object]$Conductor

    GlobalCondenser([object]$mappedCondenserAdapter, [object]$conductor) {
        $this.MappedCondenserAdapter = $mappedCondenserAdapter
        $this.Conductor = $conductor
    }

    [object] Condense($CondenseProposal, $CancellationToken = $null) {
        $signal = [Signal]::Start([object]::new()) | Select-Object -Last 1
        $result = $this.LoadItem($CondenseProposal, $signal.Result, $CondenseProposal.Wire, $CondenseProposal.WireMergeType, $CondenseProposal.Reload, $CondenseProposal.LoadLevel, $CondenseProposal.AutoRunConductionLevel)
        $signal.MergeSignal($result)
        return $signal
    }

    [object] Invoke($Slot, $Proposal, $CancellationToken = $null) {
        $signal = [Signal]::Start() | Select-Object -Last 1
        $result = $this.Condense($Proposal)
        $signal.MergeSignal($result)
        $signal.Result = $result.Result
        return $signal
    }

    [object] LoadItemContent($Wire, [bool]$Reload = $false) {
        $signal = [Signal]::Start() | Select-Object -Last 1

        if ([string]::IsNullOrWhiteSpace($Wire.VirtualPath)) {
            $signal.LogCritical("Wire has empty VirtualPath: $($Wire.Identifier)")
            return $signal
        }

        $documentSignal = $null

        if ($Wire.CatalogService) {
            $documentSignal = $this.Conductor.MappedStorageService.ReadDynamic(
                $Wire.VirtualPath,
                $Wire.DocumentFormat,
                "tokens",
                $Wire.Version,
                $Wire.Identifier,
                $Wire.Key
            )
        }

        if (-not $documentSignal -or $documentSignal.Failure) {
            $documentSignal = $this.Conductor.MappedStorageService.ReadDynamic(
                $Wire.VirtualPath,
                $Wire.DocumentFormat,
                "tokens",
                $Wire.Version,
                $Wire.Identifier,
                $Wire.Key
            )
        }

        if ($signal.MergeSignalAndVerifySuccess($documentSignal) -and $documentSignal.Result) {
            $Wire.ContentDynamic = $documentSignal.Result
            $Wire.ContentString = ($documentSignal.Result | ConvertTo-Json -Depth 10)
        }

        return $signal
    }

    [void] AddOrReplaceOutput($Feedback, $ResultOutput) {
        $item = $Feedback.WireOutputDictionary | Where-Object { $_.Key -eq $ResultOutput.Key }

        if (-not $item) {
            $Feedback.WireOutputDictionary += $ResultOutput
        } elseif ($item.Content -ne $ResultOutput.Content) {
            $item.Content = $ResultOutput.Content
        }
    }

    [object] LoadItemLeadContent($Proposal, $Feedback, $Wire, [bool]$Reload = $false) {
        $signal = [Signal]::Start() | Select-Object -Last 1

        if ($Wire.LeadWireIdentifier) {
            $signal.Result = ($Proposal.GetWires() | Where-Object { $_.Identifier -eq $Wire.LeadWireIdentifier -and $_.CatalogService -eq $Wire.CatalogService })[0]
            if (-not $signal.Result) {
                $signal.Result = ($Proposal.GetWires() | Where-Object { $_.Identifier -eq $Wire.LeadWireIdentifier })[0]
            }

            if (-not $signal.Result) {
                $signal.LogCritical("Missing Lead Wire: $($Wire.LeadWireIdentifier)")
            } else {
                $signal.MergeSignal($this.LoadItem($Proposal, $Feedback, $signal.Result, $Reload))
            }
        }

        return $signal
    }

    [object] LoadItemJacketContent($Proposal, $Feedback, $Wire, [bool]$Reload = $false) {
        $signal = [Signal]::Start() | Select-Object -Last 1

        if ($Wire.MergeJacket -and $Wire.JacketIdentifier) {
            $signal.Result = ($Proposal.GetWires() | Where-Object { $_.Identifier -eq $Wire.JacketIdentifier -and $_.CatalogService -eq $Wire.CatalogService })[0]
            if (-not $signal.Result) {
                $signal.Result = ($Proposal.GetWires() | Where-Object { $_.Identifier -eq $Wire.JacketIdentifier })[0]
            }

            if (-not $signal.Result) {
                $signal.LogCritical("Missing Jacket Wire: $($Wire.JacketIdentifier)")
            } else {
                $signal.MergeSignal($this.LoadItem($Proposal, $Feedback, $signal.Result, $Reload))
            }
        }

        return $signal
    }

    [object] LoadItemGroundContent($Proposal, $Feedback, $Wire, [bool]$Reload = $false) {
        $signal = [Signal]::Start() | Select-Object -Last 1

        if ($Wire.GroundWireIdentifier) {
            $signal.Result = ($Proposal.GetWires() | Where-Object { ($_.Version -eq $Wire.GroundWireIdentifier -or $_.Identifier -eq $Wire.GroundWireIdentifier) -and $_.CatalogService -eq $Wire.CatalogService })[0]
            if (-not $signal.Result) {
                $signal.Result = ($Proposal.GetWires() | Where-Object { $_.Identifier -eq $Wire.GroundWireIdentifier -or $_.Version -eq $Wire.GroundWireIdentifier })[0]
            }

            if (-not $signal.Result) {
                $signal.LogCritical("Missing Ground Wire: $($Wire.GroundWireIdentifier)")
            } else {
                $signal.MergeSignal($this.LoadItem($Proposal, $Feedback, $signal.Result, $Reload))
            }
        }

        return $signal
    }

    [object] LoadItemCrossContent($Proposal, $Feedback, $Wire, [bool]$Reload = $false) {
        $signal = [Signal]::Start() | Select-Object -Last 1

        if ($Wire.CrossWireIdentifier) {
            $signal.Result = ($Proposal.GetWires() | Where-Object { $_.Identifier -eq $Wire.CrossWireIdentifier })[0]

            if ($signal.Result) {
                $signal.MergeSignal($this.LoadItem($Proposal, $Feedback, $signal.Result, $Reload))
            }
        }

        return $signal
    }

    [object] CondenseWires($Proposal, $Feedback, $LeadWire, $CircuitWire, [bool]$Force, [bool]$MergeOnly, $Token = $null, $LeadNestPath = $null) {
        $signal = [Signal]::Start() | Select-Object -Last 1

        $mergeProposal = [PSCustomObject]@{
            LeadWire       = $LeadWire.ContentDynamic
            CircuitWire    = $CircuitWire.ContentDynamic
            LeadNestPath   = $LeadNestPath
            PerformMergeOnly = $MergeOnly
        }

        $mergeSignal = $this.Conductor.MappedCondenserAdapter.MergeCondenser.Invoke("", $mergeProposal)

        if ($mergeSignal.Success) {
            $signal.Result = $mergeSignal.Result
            $CircuitWire.CondensedDynamic = $signal.Result.Result
        }

        return $signal
    }

    [object] LoadItem($Proposal, $Feedback, $Wire, $WireMergeType = "Unspecified", [bool]$Reload = $false, [int]$LoadLevel = 0, [int]$AutoRunConductionLevel = -1) {
        $signal = [Signal]::Start($Feedback) | Select-Object -Last 1

        if ($Reload) {
            $loadResult = $this.LoadItemContent($Wire, $Reload)
            if (-not $signal.MergeSignalAndVerifySuccess($loadResult)) {
                return $signal
            }
        }

        return $signal
    }

    static [object] GetProposal($GetWires, $Wire, $WireMergeType = "Unspecified", [bool]$Reload = $false, [int]$LoadLevel = 0, [int]$AutoRunConductionLevel = -1) {
        return [PSCustomObject]@{
            Wire                  = $Wire
            WireMergeType         = $WireMergeType
            Reload                = $Reload
            LoadLevel             = $LoadLevel
            AutoRunConductionLevel = $AutoRunConductionLevel
            GetWires              = $GetWires
        }
    }
}
