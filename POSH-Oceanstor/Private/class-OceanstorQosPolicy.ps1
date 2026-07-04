class OceanstorQosPolicy {
    hidden [pscustomobject]${Session}
    hidden [pscustomobject]${WebSession}

    [string]$Id
    [string]$Name
    [string]$Description
    [string]${Health Status}
    [string]${Running Status}
    [bool]$Enabled
    [string]${IO Type}
    [string]$Priority
    [string]${Policy Type}
    [string]${Schedule Policy}
    [string]${Schedule Start Time}
    [string]${Start Time}
    [string]$Duration
    [string]${Cycle Set}
    [string]${Max Bandwidth}
    [string]${Max IOPS}
    [string]${Min Bandwidth}
    [string]${Min IOPS}
    [string]$Latency
    [string]${Burst Bandwidth}
    [string]${Burst IOPS}
    [string]${Burst Time}
    [string[]]${Lun List}
    [string[]]${FS List}
    [string[]]${Host List}
    [string]${Parent Policy Id}
    [string]${Parent Policy Name}
    [string[]]${Policy List}
    [string]${vStore Id}
    [string]${vStore Name}

    OceanstorQosPolicy([pscustomobject]$PolicyReceived, [pscustomobject]$WebSession) {
        $this.Session = $WebSession
        $this.WebSession = $WebSession
        $this.Id = $PolicyReceived.ID
        $this.Name = $PolicyReceived.NAME
        $this.Description = $PolicyReceived.DESCRIPTION
        $this.{Health Status} = switch ([string]$PolicyReceived.HEALTHSTATUS) {
            '1' { 'Normal' }
            default { $PolicyReceived.HEALTHSTATUS }
        }
        $this.{Running Status} = switch ([string]$PolicyReceived.RUNNINGSTATUS) {
            '2' { 'Running' }
            '45' { 'Inactive' }
            '46' { 'Idle' }
            default { $PolicyReceived.RUNNINGSTATUS }
        }
        $this.Enabled = switch ([string]$PolicyReceived.ENABLESTATUS) {
            'true' { $true }
            'True' { $true }
            '1' { $true }
            'false' { $false }
            'False' { $false }
            '0' { $false }
            default { $false }
        }
        $this.{IO Type} = switch ([string]$PolicyReceived.IOTYPE) {
            '2' { 'ReadWrite' }
            '3' { 'Split' }
            default { $PolicyReceived.IOTYPE }
        }
        $this.Priority = switch ([string]$PolicyReceived.PRIORITY) {
            '0' { 'Normal' }
            '1' { 'High' }
            default { $PolicyReceived.PRIORITY }
        }
        $this.{Policy Type} = switch ([string]$PolicyReceived.POLICYTYPE) {
            '0' { 'Normal' }
            '1' { 'Hierarchical' }
            default { $PolicyReceived.POLICYTYPE }
        }
        $this.{Schedule Policy} = switch ([string]$PolicyReceived.SCHEDULEPOLICY) {
            '0' { 'Once' }
            '1' { 'Daily' }
            '2' { 'Weekly' }
            default { $PolicyReceived.SCHEDULEPOLICY }
        }
        $this.{Schedule Start Time} = $PolicyReceived.SCHEDULESTARTTIME
        $this.{Start Time} = $PolicyReceived.STARTTIME
        $this.Duration = $PolicyReceived.DURATION
        $this.{Cycle Set} = $PolicyReceived.CYCLESET
        $this.{Max Bandwidth} = $PolicyReceived.MAXBANDWIDTH
        $this.{Max IOPS} = $PolicyReceived.MAXIOPS
        $this.{Min Bandwidth} = $PolicyReceived.MINBANDWIDTH
        $this.{Min IOPS} = $PolicyReceived.MINIOPS
        $this.Latency = $PolicyReceived.LATENCY
        $this.{Burst Bandwidth} = $PolicyReceived.BURSTBANDWIDTH
        $this.{Burst IOPS} = $PolicyReceived.BURSTIOPS
        $this.{Burst Time} = $PolicyReceived.BURSTTIME
        $this.{Lun List} = @($PolicyReceived.LUNLIST)
        $this.{FS List} = @($PolicyReceived.FSLIST)
        $this.{Host List} = @($PolicyReceived.HOSTLIST)
        $this.{Parent Policy Id} = $PolicyReceived.PARENTPOLICYID
        $this.{Parent Policy Name} = $PolicyReceived.PARENTPOLICYNAME
        $this.{Policy List} = @($PolicyReceived.POLICYLIST)
        $this.{vStore Id} = $PolicyReceived.vstoreId
        $this.{vStore Name} = $PolicyReceived.vstoreName
    }

    [psobject] Delete() {
        return Remove-DMQosPolicy -WebSession $this.Session -Id $this.Id -Confirm:$false
    }
}
