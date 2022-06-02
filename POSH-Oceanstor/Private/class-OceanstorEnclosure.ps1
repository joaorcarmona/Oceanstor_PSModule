class OceanStorEnclosure
{
    #Define Properties
    [string]${Id}
    [string]${Name}
    [string]${Model}
    [string]${Type}
    [string]${Parentid}
    [string]${Parent Type}
    [string]${Health Status}
    [string]${Running Status}
    [string]${Serial Number}
    [string]${MAC Address}
    [string]${Expander Depth}
    [string]${Expander Port}
    [string]${Height}
    [string]${Location}
    [string]${Logic Type}
    [string]${Location UID}
    [string]${Temperature}
    [string]${elabel}

    OceanStorEnclosure ([array]$encReceived)
    {
        $this.{elabel} = $encReceived.ELABEL
        $this.{Expander Depth} = $encReceived.EXPANDERDEPTH
        $this.{Expander Port} = $encReceived.EXPANDERPORT

        switch($encReceived.HEALTHSTATUS)
		{
			0 {$this.{Health Status} = "unknown"}
			1 {$this.{Health Status} = "normal"}
			2 {$this.{Health Status} = "faulty"}
		}

        $this.{Height} = $encReceived.HEIGHT
        $this.{Id} = $encReceived.ID
        $this.{Location} = $encReceived.LOCATION

        switch($encReceived.LOGICTYPE)
		{
			0 {$this.{Logic Type} = "Expansion Controller (Disk Enclosure)"}
			1 {$this.{Logic Type} = "Controller Enclosure"}
			2 {$this.{Logic Type} = "data switch"}
            3 {$this.{Logic Type} = "management switch"}
            4 {$this.{Logic Type} = "management server"}
		}
        $this.{MAC Address} = $encReceived.MACADDRESS

        switch($encReceived.MODEL)
		{
			0 {$this.{Model} = "baseboard management controller (BMC) enclosure"}
            1 {$this.{Model} = "2 U 2-controller 12-slot 3.5-inch 6Gbit/s SAS controller enclosure"}
            2 {$this.{Model} = "2 U 2-controller 24-slot 6 Gbit/s SAS controller enclosure"}
            16 {$this.{Model} = "2 U 12-slot 3.5-inch 6 Gbit/s SAS disk enclosure"}
            17 {$this.{Model} = "2 U SAS 24-disk expansion enclosure"}
            18 {$this.{Model} = "4 U 24-slot 3.5-inch 12 Gbit/s SAS disk enclosure"}
            19 {$this.{Model} = "4 U Fibre Channel 24-disk expansion enclosure"}
            20 {$this.{Model} = "1 U PCIe data switch"}
            21 {$this.{Model} = "4 U 75-slot 3.5-inch 6 Gbit/s SAS disk enclosure"}
            22 {$this.{Model} = "service processor (SVP)"}
            97 {$this.{Model} = "6 U 4-controller enclosure"}
            96 {$this.{Model} = "3 U 2-controller enclosure"}
            24 {$this.{Model} = "2 U 25-slot 2.5-inch 6 Gbit/s SAS disk enclosure"}
            25 {$this.{Model} = "4 U 24-slot 3.5-inch 6 Gbit/s SAS disk enclosure"}
            26 {$this.{Model} = "2 U 2-controller 25-slot 2.5-inch 6 Gbit/s SAS controller enclosure"}
            23 {$this.{Model} = "2 U 2-controller 12-slot 3.5-inch 6 Gbit/s SAS controller"}
            39 {$this.{Model} = "4 U 75-slot 3.5-inch 12 Gbit/s SAS disk enclosure"}
            65 {$this.{Model} = "2 U 25-slot 2.5-inch 12 Gbit/s SAS disk enclosure"}
            66 {$this.{Model} = "4 U 24-slot 3.5-inch 12 Gbit/s SAS disk enclosure"}
            40 {$this.{Model} = "2 U 2-controller 25-slot 2.5-inch 12 Gbit/s SAS controller enclosure"}
            37 {$this.{Model} = "2 U 2-controller 12-slot 3.5-inch 6 Gbit/s SAS controller enclosure"}
            38 {$this.{Model} = "2 U 2-controller 25-slot 2.5-inch 6 Gbit/s SAS controller enclosure"}
            default {$this.{Model} ="unknown"}
		}

        $this.{Name} = $encReceived.NAME
        $this.{Parentid} = $encReceived.PARENTID

        switch($encReceived.PARENTTYPE)
		{
			205 {$this.{Parent Type} = "Bay"}
		}

        switch($encReceived.RUNNINGSTATUS)
		{
			0 {$this.{Running Status} = "unknown"}
			1 {$this.{Running Status} = "normal"}
			2 {$this.{Running Status} = "running"}
            5 {$this.{Running Status} = "sleep in High Temperature"}
            27 {$this.{Running Status} = "online"}
            28 {$this.{Running Status} = "offline"}
		}

        $this.{Serial Number} = $encReceived.SERIALNUM

        switch($encReceived.SWITCHSTATUS)
		{
			0 {$this.{Location UID} = "on"}
			1 {$this.{Location UID} = "off"}
        }

        $this.{Temperature} = $encReceived.TEMPERATURE
        $this.{Type} = $encReceived.TYPE
    }
}