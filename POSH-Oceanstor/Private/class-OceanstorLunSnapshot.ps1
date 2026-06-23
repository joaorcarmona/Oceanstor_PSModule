class OceanstorLunSnapshot {
    hidden [pscustomobject]${Session}
	hidden [pscustomobject]${WebSession}
    hidden [string]${Object Type}
    [string]${Id}
    [string]${Name}
    [string]${Description}
    [string]${Source Lun Id}
    [string]${Source Lun Name}
    [string]${Health Status}
    [string]${Running Status}
    [string]${WWN}
    [int64]${User Capacity}
    [int64]${Consumed Capacity}
    [string]${IO Priority}
    [boolean]${Read Only}
    hidden [boolean]${Deleted}

    OceanstorLunSnapshot([pscustomobject]$SnapshotReceived, [pscustomobject]$WebSession) {
        $this.Session = $WebSession
		$this.WebSession = $WebSession
        $this.{Object Type} = 'LUN Snapshot'
        $this.Id = $SnapshotReceived.ID
        $this.Name = $SnapshotReceived.NAME
        $this.Description = $SnapshotReceived.DESCRIPTION
        $this.{Source Lun Id} = $SnapshotReceived.SOURCELUNID
        $this.{Source Lun Name} = $SnapshotReceived.SOURCELUNNAME
        $this.WWN = $SnapshotReceived.WWN
        $this.{User Capacity} = $SnapshotReceived.USERCAPACITY
        $this.{Consumed Capacity} = $SnapshotReceived.CONSUMEDCAPACITY
        $this.{Read Only} = $SnapshotReceived.isReadOnly

        switch ($SnapshotReceived.HEALTHSTATUS) {
            1 { $this.{Health Status} = 'Normal' }
            2 { $this.{Health Status} = 'Faulty' }
            default { $this.{Health Status} = $SnapshotReceived.HEALTHSTATUS }
        }

        $this.{Running Status} = $SnapshotReceived.RUNNINGSTATUS

        switch ($SnapshotReceived.IOPRIORITY) {
            1 { $this.{IO Priority} = 'Low' }
            2 { $this.{IO Priority} = 'Medium' }
            3 { $this.{IO Priority} = 'High' }
            default { $this.{IO Priority} = $SnapshotReceived.IOPRIORITY }
        }
    }

    [psobject] DeleteSnapShot() {
        $response = Remove-DMLunSnapShot -WebSession $this.Session -SnapShotName $this.Name

        if ($null -ne $response -and $response.Code -eq 0) {
            $this.Deleted = $true
            $this.Session = $null
		$this.WebSession = $null
            $this.{Object Type} = 'Deleted LUN Snapshot'
            $this.Id = $null
            $this.Name = $null
            $this.Description = $null
            $this.{Source Lun Id} = $null
            $this.{Source Lun Name} = $null
            $this.{Health Status} = $null
            $this.{Running Status} = $null
            $this.WWN = $null
            $this.{User Capacity} = 0
            $this.{Consumed Capacity} = 0
            $this.{IO Priority} = $null
            $this.{Read Only} = $false
        }

        return $response
    }

    [psobject] Activate() {
        return (Enable-DMLunSnapshot -WebSession $this.Session -SnapShotName $this.Name)
    }

    [psobject] Reactivate() {
        return (Restart-DMLunSnapshot -WebSession $this.Session -SnapShotName $this.Name)
    }

    [psobject] Expand([uint64]$UserCapacity) {
        return (Resize-DMLunSnapshot -WebSession $this.Session -SnapShotName $this.Name -UserCapacity $UserCapacity)
    }

    [psobject] Rollback() {
        return (Restore-DMLunSnapshot -WebSession $this.Session -SnapShotName $this.Name)
    }

    [psobject] Rollback([string]$RollbackSpeed) {
        return (Restore-DMLunSnapshot -WebSession $this.Session -SnapShotName $this.Name -RollbackSpeed $RollbackSpeed)
    }

    [psobject] CreateCopy() {
        return (New-DMLunSnapshotCopy -WebSession $this.Session -SourceSnapShotName $this.Name)
    }

    [psobject] CreateCopy([string]$SnapshotCopyName) {
        return (New-DMLunSnapshotCopy -WebSession $this.Session -SourceSnapShotName $this.Name -SnapshotCopyName $SnapshotCopyName)
    }

    [psobject] CreateCopy([string]$SnapshotCopyName, [string]$Description) {
        return (New-DMLunSnapshotCopy -WebSession $this.Session -SourceSnapShotName $this.Name -SnapshotCopyName $SnapshotCopyName -Description $Description)
    }
}

