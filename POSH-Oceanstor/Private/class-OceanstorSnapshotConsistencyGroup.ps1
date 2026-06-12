class OceanstorSnapshotConsistencyGroup {
    hidden [pscustomobject]${Session}
	hidden [pscustomobject]${WebSession}
    [string]${Id}
    [string]${Name}
    [string]${Description}
    [string]${Protection Group Id}
    [string]${Protection Group Name}
    [string]${Running Status}
    [string]${Restore Speed}
    [string]${Timestamp}
    [string]${vStore ID}
    [string]${vStore Name}

    OceanstorSnapshotConsistencyGroup([pscustomobject]$GroupReceived, [pscustomobject]$WebSession) {
        $this.Session = $WebSession
		$this.WebSession = $WebSession
        $this.Id = $GroupReceived.ID
        $this.Name = $GroupReceived.NAME
        $this.Description = $GroupReceived.DESCRIPTION
        $this.{Protection Group Id} = $GroupReceived.PARENTID
        $this.{Protection Group Name} = $GroupReceived.PARENTNAME
        $this.Timestamp = $GroupReceived.TIMESTAMP
        $this.{vStore ID} = $GroupReceived.vstoreId
        $this.{vStore Name} = $GroupReceived.vstoreName

        switch ([string]$GroupReceived.RUNNINGSTATUS) {
            '43' { $this.{Running Status} = 'Activated' }
            '44' { $this.{Running Status} = 'Rolling Back' }
            '45' { $this.{Running Status} = 'Unactivated' }
            '53' { $this.{Running Status} = 'Initializing' }
            '106' { $this.{Running Status} = 'Deleting' }
            default { $this.{Running Status} = $GroupReceived.RUNNINGSTATUS }
        }

        switch ([string]$GroupReceived.RESTORESPEED) {
            '1' { $this.{Restore Speed} = 'Low' }
            '2' { $this.{Restore Speed} = 'Medium' }
            '3' { $this.{Restore Speed} = 'High' }
            '4' { $this.{Restore Speed} = 'Highest' }
            default { $this.{Restore Speed} = $GroupReceived.RESTORESPEED }
        }
    }

    [psobject] Delete() {
        return (Remove-DMSnapshotConsistencyGroup -WebSession $this.Session -Name $this.Name)
    }

    [psobject] Activate() {
        return (Enable-DMSnapshotConsistencyGroup -WebSession $this.Session -Name $this.Name)
    }

    [psobject] Reactivate() {
        return (Restart-DMSnapshotConsistencyGroup -WebSession $this.Session -Name $this.Name)
    }

    [psobject] Rollback() {
        return (Restore-DMSnapshotConsistencyGroup -WebSession $this.Session -Name $this.Name)
    }

    [psobject] Rollback([string]$RestoreSpeed) {
        return (Restore-DMSnapshotConsistencyGroup -WebSession $this.Session -Name $this.Name -RestoreSpeed $RestoreSpeed)
    }

    [psobject] CreateCopy() {
        return (New-DMSnapshotConsistencyGroupCopy -WebSession $this.Session -SourceName $this.Name)
    }

    [psobject] CreateCopy([string]$Name) {
        return (New-DMSnapshotConsistencyGroupCopy -WebSession $this.Session -SourceName $this.Name -Name $Name)
    }
}


