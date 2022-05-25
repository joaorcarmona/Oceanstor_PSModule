class OceanStorNFSShare
{
    [string]${Id}
    [string]${Name}
    [string]${Share Path}
    [string]${Type}
    [string]${Character Enconding}
    [string]${Description}
    [string]${Audit Items}
    [string]${Enable Snapshot Visible}
    [string]${FileSystem ID}
    [string]${NFS Lock Policy}
    [string]${vStore ID}
    [string]${vStore Name}

    OceanStorNFSShare ([array]$NFSShare)
    {
        $this.{Id} = $NFSShare.ID
        $this.{Name} = $NFSShare.NAME
        $this.{Share Path} = $NFSShare.SHAREPATH
        $this.{Type} = $NFSShare.TYPE

        switch ($NFSShare.CHARACTERENCODING)
        {
            0 {$this.{Character Enconding} = "UTF-8"}
            11 {$this.{Character Enconding} = "ZH"}
            12 {$this.{Character Enconding} = "GBK"}
            13 {$this.{Character Enconding} = "EUC-TW"}
            14 {$this.{Character Enconding} = "BIG5"}
            21 {$this.{Character Enconding} = "EUC-JP"}
            22 {$this.{Character Enconding} = "JIS"}
            23 {$this.{Character Enconding} = "S-JIS"}
            30 {$this.{Character Enconding} = "DE"}
            31 {$this.{Character Enconding} = "PT"}
            32 {$this.{Character Enconding} = "ES"}
            33 {$this.{Character Enconding} = "FR"}
            34 {$this.{Character Enconding} = "IT"}
            40 {$this.{Character Enconding} = "KO"}
        }

        $this.{Description} = $NFSShare.DESCRIPTION
        $this.{FileSystem ID} = $NFSShare.FSID
        $this.{Audit Items} = $NFSShare.AUDITITEMS #TODO

        switch ($NFSShare.ENABLESHOWSNAPSHOT)
        {
            true {$this.{Enable Snapshot Visible} = "enabled"}
            false {$this.{Enable Snapshot Visible} = "disabled"}
        }

        switch ($NFSShare.LOCKPOLICY)
        {
            0 {$this.{NFS Lock Policy} = "Advisoring Locking"}
            1 {$this.{NFS Lock Policy} = "Mandatory Locking"}
        }

        $this.{vStore ID} = $NFSShare.vstoreId
        $this.{vStore Name} = $NFSShare.vstoreName

    }
}