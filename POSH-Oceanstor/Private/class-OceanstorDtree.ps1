class OceanStorDtree {
    hidden [pscustomobject]${Session}
	hidden [pscustomobject]${WebSession}
    #Define Properties
    [string]$Id
    [string]$Name
    [string]$parentId
    [string]${Quota Switch}
    [string]${Quota Switch Status}
    [string]${Share Type}
    [bool]${Quota Configured}
    [string]${vStore Id}
    [string]${vStore Name}
    [string]${Security Style}
    [string]${Quota Count}
    [string]${Replication Count}
    [string]${Snapshot Count}
    [string]${Locking Policy}
    
    OceanStorDtree ([array]$dtree, [pscustomobject]$WebSession)
    {
        $this.Session = $WebSession
		$this.WebSession = $WebSession
        $this.Id = $dtree.ID
        $this.Name = $dtree.NAME
        $this.parentId = $dtree.PARENTID
        $this.{Quota Switch} = $dtree.QUOTASWITCH
        $this.{Quota Switch Status} = $dtree.QUOTASWITCHSTATUS
        $this.{Share Type} = $dtree.SHARETYPE
        $this.{Quota Configured} = [string]$dtree.ISQUOTACONFIGURED -match '^(?i:true|1)$'
        $this.{vStore Id} = $dtree.vstoreId
        $this.{vStore Name} = $dtree.vstoreName
        $this.{Security Style} = $dtree.securityStyle
        $this.{Quota Count} = $dtree.quotaCfgCount
        $this.{Replication Count} = $dtree.replicationCount
        $this.{Snapshot Count} = $dtree.snapCount
        $this.{Locking Policy} = $dtree.nasLockingPolicy
    }

    [psobject] Delete() {
        $fs = @(Get-DMFileSystem -WebSession $this.Session | Where-Object Id -EQ $this.parentId)[0]
        return Remove-DMDTree -WebSession $this.Session -FileSystemName $fs.Name -DTreeName $this.Name -Confirm:$false
    }
}


