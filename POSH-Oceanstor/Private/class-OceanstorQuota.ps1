class OceanstorQuota {
    hidden [pscustomobject]${Session}
    hidden [pscustomobject]${WebSession}

    [string]$Id
    [string]${Parent Type}
    [string]${Parent Id}
    [string]${Quota Type}
    [string]${Account Name}
    [string]${Account Type}
    [uint64]${Space Soft Quota}
    [uint64]${Space Hard Quota}
    [uint64]${Space Used}
    [uint64]${File Soft Quota}
    [uint64]${File Hard Quota}
    [uint64]${File Used}
    [string]${vStore Id}

    OceanstorQuota ([pscustomobject]$quota, [pscustomobject]$WebSession)
    {
        $this.Session = $WebSession
        $this.WebSession = $WebSession
        $this.Id = $quota.ID
        $this.{Parent Type} = switch ([string]$quota.PARENTTYPE) {
            '40' { 'FileSystem' }
            '16445' { 'Dtree' }
            default { $quota.PARENTTYPE }
        }
        $this.{Parent Id} = $quota.PARENTID
        $this.{Quota Type} = switch ([string]$quota.QUOTATYPE) {
            '1' { 'Directory' }
            '2' { 'User' }
            '3' { 'UserGroup' }
            default { $quota.QUOTATYPE }
        }
        $this.{Account Name} = $quota.USRGRPOWNERNAME
        $this.{Account Type} = switch ([string]$quota.USRGRPTYPE) {
            '1' { 'Local' }
            '2' { 'Domain' }
            default { $quota.USRGRPTYPE }
        }
        $this.{Space Soft Quota} = [uint64]$quota.SPACESOFTQUOTA
        $this.{Space Hard Quota} = [uint64]$quota.SPACEHARDQUOTA
        $this.{Space Used} = [uint64]$quota.SPACEUSED
        $this.{File Soft Quota} = [uint64]$quota.FILESOFTQUOTA
        $this.{File Hard Quota} = [uint64]$quota.FILEHARDQUOTA
        $this.{File Used} = [uint64]$quota.FILEUSED
        $this.{vStore Id} = $quota.vstoreId
    }

    [psobject] Delete() {
        return Remove-DMQuota -WebSession $this.Session -Id $this.Id -Confirm:$false
    }
}
