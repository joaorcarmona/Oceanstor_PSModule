class OceanstorQuota {
    hidden [pscustomobject]${Session}
    hidden [pscustomobject]${WebSession}

    [string]$Id
    [string]${Parent Type}
    [string]${Parent Id}
    [string]${Quota Type}
    [string]${Account Name}
    [string]${Account Type}
    [Nullable[uint64]]${Space Soft Quota}
    [Nullable[uint64]]${Space Hard Quota}
    [Nullable[uint64]]${Space Used}
    [Nullable[uint64]]${File Soft Quota}
    [Nullable[uint64]]${File Hard Quota}
    [Nullable[uint64]]${File Used}
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
        $this.{Space Soft Quota} = [OceanstorQuota]::ToQuotaValue($quota.SPACESOFTQUOTA)
        $this.{Space Hard Quota} = [OceanstorQuota]::ToQuotaValue($quota.SPACEHARDQUOTA)
        $this.{Space Used} = [OceanstorQuota]::ToQuotaValue($quota.SPACEUSED)
        $this.{File Soft Quota} = [OceanstorQuota]::ToQuotaValue($quota.FILESOFTQUOTA)
        $this.{File Hard Quota} = [OceanstorQuota]::ToQuotaValue($quota.FILEHARDQUOTA)
        $this.{File Used} = [OceanstorQuota]::ToQuotaValue($quota.FILEUSED)
        $this.{vStore Id} = $quota.vstoreId
    }

    # OceanStor renders an unconfigured quota dimension as the INVALID_VALUE64
    # sentinel. The REST layer surfaces it as '-1' on some firmwares and as the
    # unsigned 0xFFFFFFFFFFFFFFFF form on others; both mean "no quota configured".
    # Return $null (blank) for the sentinel rather than a misleading numeric 0,
    # and to avoid the [uint64]'-1' cast that would otherwise throw.
    hidden static [Nullable[uint64]] ToQuotaValue([object]$raw) {
        if ($null -eq $raw) { return $null }
        $text = ([string]$raw).Trim()
        if ($text -eq '' -or $text -eq '-1' -or $text -eq '18446744073709551615') {
            return $null
        }
        return [uint64]$text
    }

    [psobject] Delete() {
        return Remove-DMQuota -WebSession $this.Session -Id $this.Id -Confirm:$false
    }
}
