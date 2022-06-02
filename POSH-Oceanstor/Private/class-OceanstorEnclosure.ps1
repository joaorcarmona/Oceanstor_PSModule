class OceanStorEnclosure
{
    #Define Properties
    [string]${Id}
    [string]${Name}
    [string]${Model}
    [string]${Type}
    [string]${Board Type}
    [string]${Bar Code}
    [string]${Part Number}
    [string]${Description}
    [string]$Manufactured
    [string]${Vendor Name}
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
    #[string]${elabel}

    OceanStorEnclosure ([array]$encReceived)
    {

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
            23 {$this.{Model} = "2 U 2-controller 12-slot 3.5-inch 6 Gbit/s SAS controller"}
            24 {$this.{Model} = "2 U 25-slot 2.5-inch 6 Gbit/s SAS disk enclosure"}
            25 {$this.{Model} = "4 U 24-slot 3.5-inch 6 Gbit/s SAS disk enclosure"}
            26 {$this.{Model} = "2 U 2-controller 25-slot 2.5-inch 6 Gbit/s SAS controller enclosure"}
            37 {$this.{Model} = "2 U 2-controller 12-slot 3.5-inch 6 Gbit/s SAS controller enclosure"}
            38 {$this.{Model} = "2 U 2-controller 25-slot 2.5-inch 6 Gbit/s SAS controller enclosure"}
            39 {$this.{Model} = "4 U 75-slot 3.5-inch 12 Gbit/s SAS disk enclosure"}
            40 {$this.{Model} = "2 U 2-controller 25-slot 2.5-inch 12 Gbit/s SAS controller enclosure"}
            65 {$this.{Model} = "2 U 25-slot 2.5-inch 12 Gbit/s SAS disk enclosure"}
            66 {$this.{Model} = "4 U 24-slot 3.5-inch 12 Gbit/s SAS disk enclosure"}
            69 {$this.{Model} = "4 U 24-slot 3.5-inch SAS disk enclosure"}
            96 {$this.{Model} = "3 U 2-controller enclosure"}
            97 {$this.{Model} = "6 U 4-controller enclosure"}
            112 {$this.{Model} = "4 U 4-controller controller enclosure"}
            113 {$this.{Model} = "2 U 2-controller 25-slot 2.5-inch SAS controller enclosure"}
            114 {$this.{Model} = "2 U 2-controller 12-slot 3.5-inch SAS controller enclosure"}
            115 {$this.{Model} = "2 U 2-controller 36-slot NVMe controller enclosure"}
            116 {$this.{Model} = "2 U 2-controller 25-slot 2.5-inch SAS controller enclosure"}
            117 {$this.{Model} = "2 U 2-controller 12-slot 3.5-inch SAS controller enclosure"}
            118 {$this.{Model} = "2 U 25-slot 2.5-inch smart SAS disk enclosure"}
            119 {$this.{Model} = "2 U 12-slot 3.5-inch smart SAS disk enclosure"}
            120 {$this.{Model} = "2 U 36-slot smart NVMe disk enclosure"}
            122 {$this.{Model} = "2 U 2-controller 25-slot 2.5-inch NVMe controller enclosure"}
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
            105 {$this.{Running Status} = "abnormal"}
		}

        $this.{Serial Number} = $encReceived.SERIALNUM

        switch($encReceived.SWITCHSTATUS)
		{
			0 {$this.{Location UID} = "on"}
			1 {$this.{Location UID} = "off"}
        }

        $this.{Temperature} = $encReceived.TEMPERATURE

        switch($encReceived.TYPE)
		{
			206 {$this.{Type} = "enclosure"}
		}

        #$this.{elabel} = $encReceived.ELABEL

        $labels =  get-DMparsedElabel -eLabelString $encReceived.ELABEL
        $this.{Board Type} = $labels.BoardType
        $this.{Bar Code} = $labels.BarCode
        $this.{Part Number} = $labels.Item
        $this.{Description} = $labels.Description
        $this.Manufactured = $labels.Manufactured
        $this.{Vendor Name} = $labels.VendorName

    }
}