class OceanStorController
{
    #Define Properties
    [string]${Id}
    [string]${Name}
    [string]${Board Type}
    [string]${Bar Code}
    [string]${Part Number}
    [string]${Description}
    [string]$Manufactured
    [string]${Vendor Name}
    [string]${BIOS Version}
    [string]${BMC Version}
    [string]${CPU Info}
    [string]${CPU Usage}
    #[string]${Description} => replaced by elabel description
    [string]${Dirty Page Usage}
    #[string]${elabel}
    [string]${Health Status}
    [string]${Is Master}
    [string]${Light Status}
    [string]${Location}
    [string]${Logic Version}
    [string]${Memory Size}
    [string]${Memory Usage}
    [string]${Multi-Working Mode}
    [string]${Enclosure Id}
    [string]${PCB Version}
    [string]${Role}
    [string]${Operating Mode}
    [string]${runmodelist}
    [string]${Running Status}
    [string]${SES Ver}
    [string]${Firmware Version}
    [string]${Temperature}
    [string]${Type}
    [string]${Voltage}

    OceanStorController ([array]$ctrlReceived)
    {
        $this.{BIOS Version} = $ctrlReceived.BIOSVER
        $this.{BMC Version} = $ctrlReceived.BMCVER
        $this.{CPU Info} = $ctrlReceived.CPUINFO
        $this.{CPU Usage} = $ctrlReceived.CPUUSAGE
        #$this.{Description} = $ctrlReceived.DESCRIPTION => replaced by elabel description
        $this.{Dirty Page Usage} = $ctrlReceived.DIRTYDATARATE
        #$this.{elabel} = $ctrlReceived.ELABEL

        switch($ctrlReceived.HEALTHSTATUS)
		{
			0 {$this.{Health Status} = "unknown"}
			1 {$this.{Health Status} = "normal"}
			2 {$this.{Health Status} = "faulty"}
            9 {$this.{Health Status} = "inconsistent"}
		}

        $this.{Id} = $ctrlReceived.ID

        switch($ctrlReceived.ISMASTER)
		{
			true {$this.{Is Master} = "primary"}
            false {$this.{Is Master} = "secondary"}
		}

        switch($ctrlReceived.LIGHT_STATUS)
		{
			1 {$this.{Light Status} = "off"}
			2 {$this.{Light Status} = "on"}
        }

        $this.{Location} = $ctrlReceived.LOCATION
        $this.{Logic Version} = $ctrlReceived.LOGICVER
        $this.{Memory Size} = $ctrlReceived.MEMORYSIZE
        $this.{Memory Usage} = $ctrlReceived.MEMORYUSAGE

        switch($ctrlReceived.MULTMODE)
		{
			true {$this.{Multi-Working Mode} = "supported"}
			false {$this.{Multi-Working Mode} = "not supported"}
        }

        $this.{Name} = $ctrlReceived.NAME
        $this.{Enclosure Id} = $ctrlReceived.PARENTID
        $this.{PCB Version} = $ctrlReceived.PCBVER

        switch($ctrlReceived.ROLE)
		{
			0 {$this.{Role} = "ordinary member"}
            1 {$this.{Role} = "cluster primary node"}
            2 {$this.{Role} = "cluster secondary node"}
		}

        switch($ctrlReceived.RUNMODE)
		{
			1 {$this.{Operating Mode} = "Fibre Channel"}
			2 {$this.{Operating Mode} = "FCoE/iSCSI"}
            3 {$this.{Operating Mode} = "cluster"}
        }
        $this.{runmodelist} = $ctrlReceived.RUNMODELIST

        switch($ctrlReceived.RUNNINGSTATUS)
		{
			0 {$this.{Running Status} = "unknown"}
			1 {$this.{Running Status} = "normal"}
			2 {$this.{Running Status} = "running"}
            27 {$this.{Running Status} = "online"}
            28 {$this.{Running Status} = "offline"}
		}

        $this.{SES Ver} = $ctrlReceived.SESVER
        $this.{Firmware Version} = $ctrlReceived.SOFTVER
        $this.{Temperature} = $ctrlReceived.TEMPERATURE

        switch($ctrlReceived.TYPE)
		{
			207 {$this.{Type} = "controller"}
		}
        $this.{Voltage} = $ctrlReceived.VOLTAGE

        $labels =  get-DMparsedElabel -eLabelString $ctrlReceived.ELABEL
        $this.{Board Type} = $labels.BoardType
        $this.{Bar Code} = $labels.BarCode
        $this.{Part Number} = $labels.Item
        $this.{Description} = $labels.Description
        $this.Manufactured = $labels.Manufactured
        $this.{Vendor Name} = $labels.VenderName
    }

}