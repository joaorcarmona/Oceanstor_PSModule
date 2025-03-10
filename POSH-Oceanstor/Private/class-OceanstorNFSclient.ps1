class OceanstorNFSclient
{
    [string]${Name}
    [string]${Id}
    [string]${Parent Id}
    [string]${Access Permission}
    [string]${WriteMode}
    [string]${Permission Constrain}
    [string]${Root Permission Constrain}
    [string]${Source Port Verification}
    [string]${Charset Encoding}
    [string]${vStore Id}
    [string]${NFS Share Name}
    [string]${Mounting Security Type}
    [string]${NTFS Unix Security Option}
    [string]${NFSv4 ACL Protection}
    [string]${Ownership Mode}
    [string]${Nfs Share krb5 Mode}
    [string]${Nfs Share krb5i Mode}
    [string]${Nfs Share krb5p Mode}
    #[string]${vStore Name} unsupported

    OceanstorNFSclient ([array]$NFSExport)
    {
        $this.{Name} = $NFSExport.NAME
        $this.{Id} = $NFSExport.ID
        $this.{Parent Id} = $NFSExport.PARENTID 

        switch ($NFSExport.ACCESSVAL){
            0 {$this.{Access Permission} = "read-only"}
            1 {$this.{Access Permission} = "read and write"}
            5 {$this.{Access Permission} = "no permission"}
        }

        switch ($NFSExport.SYNC){
            0 {$this.{WriteMode} = "synchronous"}
            1 {$this.{WriteMode} = "asynchronous"}
        }        

        switch ($NFSExport.ALLSQUASH){
            0 {$this.{Permission Constrain} = "all_squash"}
            1 {$this.{Permission Constrain} = "no_all_squash"}
        }

        switch ($NFSExport.ROOTSQUASH){
            0 {$this.{Root Permission Constrain} = "all_squash"}
            1 {$this.{Root Permission Constrain} = "no_all_squash"}
        }

        switch ($NFSExport.SECURE){
            0 {$this.{Source Port Verification} = "secure"}
            1 {$this.{Source Port Verification} = "insecure"}
        }

        switch ($NFSExport.CHARSET){
            0 {$this.{Charset Encoding} = "UTF-8"}
            11 {$this.{Charset Encoding} = "ZH"}
            12 {$this.{Charset Encoding} = "GBK"}
            13 {$this.{Charset Encoding} = "EUC-TW"}
            14 {$this.{Charset Encoding} = "BIG5"}
            21 {$this.{Charset Encoding} = "EUC-JP"}
            22 {$this.{Charset Encoding} = "JIS"}
            23 {$this.{Charset Encoding} = "S-JIS"}
            30 {$this.{Charset Encoding} = "DE"}
            31 {$this.{Charset Encoding} = "PT"}
            32 {$this.{Charset Encoding} = "ES"}
            33 {$this.{Charset Encoding} = "FR"}
            34 {$this.{Charset Encoding} = "IT"}
            40 {$this.{Charset Encoding} = "KO"}
            41 {$this.{Charset Encoding} = "AR"}
            42 {$this.{Charset Encoding} = "CS"}
            43 {$this.{Charset Encoding} = "DA"}
            44 {$this.{Charset Encoding} = "FI"}
            45 {$this.{Charset Encoding} = "HE"}
            46 {$this.{Charset Encoding} = "HR"}
            47 {$this.{Charset Encoding} = "HU"}
            48 {$this.{Charset Encoding} = "NO"}
            49 {$this.{Charset Encoding} = "NL"}
            50 {$this.{Charset Encoding} = "PL"}
            51 {$this.{Charset Encoding} = "RO"}
            52 {$this.{Charset Encoding} = "RU"}
            53 {$this.{Charset Encoding} = "SK"}
            54 {$this.{Charset Encoding} = "SL"}
            55 {$this.{Charset Encoding} = "SV"}
            56 {$this.{Charset Encoding} = "TR"}
            60 {$this.{Charset Encoding} = "EN-US"}
            61 {$this.{Charset Encoding} = "EUC-KR"}
            65535 {$this.{Charset Encoding} = "default"}
   
        }

        $this.{vStore Id} = $NFSExport.vstoreId
        $this.{NFS Share Name} = $NFSExport.SHARENAME
 
        switch ($NFSExport.securityType){
            0 {$this.{Mounting Security Type} = "unix"}
            1 {$this.{Mounting Security Type} = "none"}
            2 {$this.{Mounting Security Type} = "none_unix"}
        }        

        switch ($NFSExport.ntfsUnixSecurityOps){
            0 {$this.{NTFS Unix Security Option} = "fail"}
            1 {$this.{NTFS Unix Security Option} = "ignore"}
        }

        switch ($NFSExport.v4AclPreserve){
            0 {$this.{NFSv4 ACL Protection} = "enable"}
            1 {$this.{NFSv4 ACL Protection} = "disable"}
        }

        switch ($NFSExport.chownMode){
            0 {$this.{Ownership Mode} = "restricted"}
            1 {$this.{Ownership Mode} = "unrestricted"}
        }

        switch ($NFSExport.ACCESSKRB5){
            0 {$this.{Nfs Share krb5 Mode} = "read-only"}
            1 {$this.{Nfs Share krb5 Mode} = "read and write"}
            5 {$this.{Nfs Share krb5 Mode} = "no permission"}
        }

        switch ($NFSExport.ACCESSKRB5I){
            0 {$this.{Nfs Share krb5i Mode} = "read-only"}
            1 {$this.{Nfs Share krb5i Mode} = "read and write"}
            5 {$this.{Nfs Share krb5i Mode} = "no permission"}
        }

        switch ($NFSExport.ACCESSKRB5P){
            0 {$this.{Nfs Share krb5p Mode} = "read-only"}
            1 {$this.{Nfs Share krb5p Mode} = "read and write"}
            5 {$this.{Nfs Share krb5p Mode} = "no permission"}
        }
        
        #$this.{vStore Name} = $NFSExport.vstoreName - unsupported
    }
}