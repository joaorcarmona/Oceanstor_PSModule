class OceanstorHostinitiatorNVMe {
    hidden [pscustomobject]${Session}
    [string]${Id}
    [string]${Name}
    [string]${Host Id}
    [string]${Host Name}
    [string]${Type}
    [string]${Health Status}
    [string]${Running Status}
    [boolean]${Is Free}
    [string]${Host IP}
    [string]${vStore ID}
    [string]${vStore Name}

    OceanstorHostinitiatorNVMe([array]$initiator, [pscustomobject]$Session) {
        $this.Session = $Session
        $this.Id = $initiator.ID
        $this.Name = $initiator.NAME
        $this.{Host Id} = $initiator.PARENTID
        $this.{Host Name} = $initiator.PARENTNAME
        $this.{Host IP} = $initiator.hostIP
        $this.{vStore ID} = $initiator.vstoreId
        $this.{vStore Name} = $initiator.vstoreName
        $this.{Is Free} = [string]$initiator.ISFREE -match '^(?i:true|1)$'

        if ([string]$initiator.TYPE -eq '57870') { $this.Type = 'NVMe over RoCE Initiator' }
        if ([string]$initiator.HEALTHSTATUS -eq '1') { $this.{Health Status} = 'Normal' }
        switch ([string]$initiator.RUNNINGSTATUS) {
            '0' { $this.{Running Status} = 'Unknown' }
            '27' { $this.{Running Status} = 'Online' }
            '28' { $this.{Running Status} = 'Offline' }
        }
    }
}
