class OceanstorFileSystemSnapshot {
    hidden [pscustomobject]${Session}
	hidden [pscustomobject]${WebSession}
    [string]${Id}
    [string]${Name}
    [string]${Description}
    [string]${Source File System Id}
    [string]${Source File System Name}
    [string]${Health Status}
    [string]${Snapshot Type}
    [string]${Rollback Status}
    [string]${Rollback Speed}
    [string]${Rollback Rate}
    [string]${Timestamp}
    [string]${Snapshot Tag}
    [string]${vStore ID}
    [string]${vStore Name}
    [boolean]${Security Snapshot}
    [boolean]${Auto Delete}

    OceanstorFileSystemSnapshot([pscustomobject]$SnapshotReceived, [pscustomobject]$WebSession) {
        $this.Session = $WebSession
		$this.WebSession = $WebSession
        $this.Id = $SnapshotReceived.ID
        $this.Name = $SnapshotReceived.NAME
        $this.Description = $SnapshotReceived.description
        $this.{Source File System Id} = $SnapshotReceived.PARENTID
        $this.{Source File System Name} = $SnapshotReceived.PARENTNAME
        $this.Timestamp = $SnapshotReceived.TIMESTAMP
        $this.{Snapshot Tag} = $SnapshotReceived.snapTag
        $this.{vStore ID} = $SnapshotReceived.vstoreId
        $this.{vStore Name} = $SnapshotReceived.vstoreName
        $this.{Rollback Rate} = $SnapshotReceived.rollbackRate
        $this.{Security Snapshot} = [string]$SnapshotReceived.isSecuritySnap -match '^(?i:true|1)$'
        $this.{Auto Delete} = [string]$SnapshotReceived.isAutoDelete -match '^(?i:true|1)$'

        switch ([string]$SnapshotReceived.HEALTHSTATUS) {
            '1' { $this.{Health Status} = 'Normal' }
            '2' { $this.{Health Status} = 'Faulty' }
            default { $this.{Health Status} = $SnapshotReceived.HEALTHSTATUS }
        }

        switch ([string]$SnapshotReceived.SNAPTYPE) {
            '1' { $this.{Snapshot Type} = 'Manual' }
            '2' { $this.{Snapshot Type} = 'Periodic' }
            '4' { $this.{Snapshot Type} = 'Internal' }
            '8' { $this.{Snapshot Type} = 'Private' }
            '16' { $this.{Snapshot Type} = 'Copy' }
            '32' { $this.{Snapshot Type} = 'Initial' }
            default { $this.{Snapshot Type} = $SnapshotReceived.SNAPTYPE }
        }

        $this.{Rollback Status} = $SnapshotReceived.rollbackStatus

        switch ([string]$SnapshotReceived.rollbackSpeed) {
            '1' { $this.{Rollback Speed} = 'Low' }
            '2' { $this.{Rollback Speed} = 'Medium' }
            '3' { $this.{Rollback Speed} = 'High' }
            '4' { $this.{Rollback Speed} = 'Highest' }
            default { $this.{Rollback Speed} = $SnapshotReceived.rollbackSpeed }
        }
    }

    [psobject] Delete() {
        return (Remove-DMFileSystemSnapshot -WebSession $this.Session -FileSystemName $this.{Source File System Name} -SnapshotName $this.Name)
    }

    [psobject] Rollback() {
        return (Restore-DMFileSystemSnapshot -WebSession $this.Session -FileSystemName $this.{Source File System Name} -SnapshotName $this.Name)
    }
}


