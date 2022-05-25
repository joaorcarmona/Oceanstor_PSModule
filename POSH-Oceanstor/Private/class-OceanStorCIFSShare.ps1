class OceanStorCIFSShare
{
    [string]${Id}
    [string]${Name}
    [string]${Share Path}
    [string]${Type}
    [string]${Sub Type}
    [string]${Description}
    [string]${FileSystem ID}
    [string]${Audit Items}
    [string]${Enable ABE}
    [string]${Enable CA}
    [string]${Enable Default ACL}
    [string]${Enable File Extension Filter}
    [string]${Enable IP Control}
    [string]${Enable Notify}
    [string]${Enable Oplock}
    [string]${Enable Previous Versions}
    [string]${Enable Snapshot Visible}
    [string]${Offline File Mode}
    [string]${vStore ID}
    [string]${vStore Name}

    OceanStorCIFSShare ([array]$cifsShare)
    {
        $this.{Id} = $cifsShare.ID
        $this.{Name} = $cifsShare.NAME
        $this.{Share Path} = $cifsShare.SHAREPATH
        $this.{Type} = $cifsShare.TYPE

        switch ($cifsShare.subType)
        {
            0 {$this.{Sub Type} = "normal"}
            1 {$this.{Sub Type} = "homedir"}
            2 {$this.{Sub Type} = "all"}
        }

        $this.{Description} = $cifsShare.DESCRIPTION
        $this.{FileSystem ID} = $cifsShare.FSID
        $this.{Audit Items} = $cifsShare.AUDITITEMS #TODO

        switch ($cifsShare.ABEENABLE)
        {
            true {$this.{Enable ABE} = "enabled"}
            false {$this.{Enable ABE} = "disabled"}
        }

        switch ($cifsShare.ENABLECA)
        {
            true {$this.{Enable CA} = "enabled"}
            false {$this.{Enable CA} = "disabled"}
        }

        switch ($cifsShare.APPLYDEFAULTACL)
        {
            true {$this.{Enable Default ACL} = "enabled"}
            false {$this.{Enable Default ACL} = "disabled"}
        }

        switch ($cifsShare.ENABLEFILEEXTENSIONFILTER)
        {
            true {$this.{Enable File Extension Filter} = "enabled"}
            false {$this.{Enable File Extension Filter} = "disabled"}
        }

        switch ($cifsShare.ENABLEIPCONTROL)
        {
            true {$this.{Enable IP Control} = "enabled"}
            false {$this.{Enable IP Control} = "disabled"}
        }

        switch ($cifsShare.ENABLENOTIFY)
        {
            true {$this.{Enable Notify} = "enabled"}
            false {$this.{Enable Notify} = "disabled"}
        }

        switch ($cifsShare.ENABLEOPLOCK)
        {
            true {$this.{Enable Oplock} = "enabled"}
            false {$this.{Enable Oplock} = "disabled"}
        }

        switch ($cifsShare.ENABLESHOWPREVIOUSVERSIONS)
        {
            true {$this.{Enable Previous Versions} = "enabled"}
            false {$this.{Enable Previous Versions} = "disabled"}
        }

        switch ($cifsShare.ENABLESHOWSNAPSHOT)
        {
            true {$this.{Enable Snapshot Visible} = "enabled"}
            false {$this.{Enable Snapshot Visible} = "disabled"}
        }

        switch ($cifsShare.OFFLINEFILEMODE)
        {
            0 {$this.{Offline File Mode} = "none"}
            1 {$this.{Offline File Mode} = "manual"}
            2 {$this.{Offline File Mode} = "documents"}
            3 {$this.{Offline File Mode} = "programs"}
        }
        $this.{vStore ID} = $cifsShare.vstoreId
        $this.{vStore Name} = $cifsShare.vstoreName

    }
}