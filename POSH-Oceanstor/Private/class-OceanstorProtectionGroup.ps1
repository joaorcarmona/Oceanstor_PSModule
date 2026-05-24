class OceanstorProtectionGroup {
    hidden [pscustomobject]${Session}
    [string]${Id}
    [string]${Name}
    [string]${Description}
    [string]${Lun Group Id}
    [string]${Lun Group Name}
    [string]${Lun Count}
    [string]${Snapshot Group Count}
    [string]${Replication Group Count}
    [string]${HyperCDP Group Count}
    [string]${Clone Group Count}
    [string]${HyperMetro Group Count}
    [string]${vStore ID}
    [string]${vStore Name}
    [string]${Usage Type}

    OceanstorProtectionGroup([pscustomobject]$ProtectionGroupReceived, [pscustomobject]$Session) {
        $this.Session = $Session
        $this.Id = $ProtectionGroupReceived.protectGroupId
        $this.Name = $ProtectionGroupReceived.protectGroupName
        $this.Description = $ProtectionGroupReceived.description
        $this.{Lun Group Id} = $ProtectionGroupReceived.lunGroupId
        $this.{Lun Group Name} = $ProtectionGroupReceived.lunGroupName
        $this.{Lun Count} = $ProtectionGroupReceived.lunNum
        $this.{Snapshot Group Count} = $ProtectionGroupReceived.snapshotGroupNum
        $this.{Replication Group Count} = $ProtectionGroupReceived.replicationGroupNum
        $this.{HyperCDP Group Count} = $ProtectionGroupReceived.cdpGroupNum
        $this.{Clone Group Count} = $ProtectionGroupReceived.cloneGroupNum
        $this.{HyperMetro Group Count} = $ProtectionGroupReceived.hyperMetroGroupNum
        $this.{vStore ID} = $ProtectionGroupReceived.vstoreId
        $this.{vStore Name} = $ProtectionGroupReceived.vstoreName

        switch ([string]$ProtectionGroupReceived.usageType) {
            '0' { $this.{Usage Type} = 'Common LUN' }
            '1' { $this.{Usage Type} = 'VVol LUN' }
            default { $this.{Usage Type} = $ProtectionGroupReceived.usageType }
        }
    }

    [psobject] Delete() {
        return (Remove-DMProtectionGroup -WebSession $this.Session -Name $this.Name)
    }

    [psobject] GetLunGroup() {
        if ([string]::IsNullOrEmpty($this.{Lun Group Id}) -or $this.{Lun Group Id} -eq '-1') {
            return $null
        }

        return @(get-DMlunGroups -WebSession $this.Session | Where-Object Id -EQ $this.{Lun Group Id})[0]
    }
}
