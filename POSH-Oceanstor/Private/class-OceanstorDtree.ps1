class OceanStorDtree {
    hidden [pscustomobject]${Session}
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
    
    OceanStorDtree ([array]$dtree, [pscustomobject]$Session)
    {
        $this.Session = $Session

    }

}
