class OceanStorBBU
{
    [string]${Id}
    [string]${Parent Id}
    [string]${Parent Type}
    [string]${Controller Id}
    [string]${PSU Location}
    [string]${name}
    [string]${ESN}
    [string]${Manufacter Date}
    [string]${Charge Times}
    [string]${Description}
    [string]${Firmware Version}
    [string]${Health Status}
    [string]${Remaining Life}
    [string]${running Status}
    [string]${Board Type}
    [string]${Part Number}
    [string]${PSU Type}
    [Int64]${voltage}
    hidden [string]$eLabel

    OceanStorBBU ([array]$bbu)
    {
        $this.{Id} = $bbu.ID
        $this.{Parent Id} = $bbu.PARENTID

        switch ($bbu.PARENTTYPE)
        {
            206 {$this.{Parent Type} = "enclosure"}
            207 {$this.{Parent Type} = "controller"}
        }

        $this.{Controller Id} = $bbu.CONTROLLERID
        $this.{PSU Location} = $bbu.LOCATION
        $this.{name} = $bbu.NAME
        $this.{Manufacter Date} = $bbu.MANUFACTUREDDATE
        $this.{Charge Times} = $bbu.CHARGETIMES

        # Need to parse the elabel to get the description and part number, as the API does not return part number and description separately for BBU, but they are included in elabel. The format of elabel is "partnumber_description", so we can split it by "_" to get the part number and description.
        $labels =  get-DMparsedElabel -eLabelString $bbu.ELABEL

        $this.{ESN} = $labels.BarCode
        $this.{Description} = $labels.Description
        $this.{Part Number} = $labels.Item
        $this.{Board Type} = $labels.BoardType
        $this.{Firmware Version} = $bbu.FIRMWAREVER

        switch ($bbu.healthstatus)
        {
            0 {$this.{Health Status} = "unknown"}
            1 {$this.{Health Status} = "normal"}
            2 {$this.{Health Status} = "faulty"}
            3 {$this.{Health Status} = "about to fail"}
            12 {$this.{Health Status} = "low battery"}
        }

        if ($bbu.REMAINLIFEDAYS -ne -1)
        {
            $this.{Remaining Life} = $bbu.REMAINLIFEDAYS
        }
        else
        {
            $age = [datetime] $bbu.MANUFACTUREDDATE
            $bbuAge = $age.AddYears(8)
            $this.{Remaining Life} = $bbuAge.ToString("yyyy-MM-dd")
        }

        switch ($bbu.RUNNINGSTATUS)
        {
            0 {$this.{running Status} = "unknown"}
            1 {$this.{running Status} = "normal"}
            2 {$this.{running Status} = "running"}
            27 {$this.{running Status} = "online"}
            28 {$this.{running Status} = "offline"}
            48 {$this.{running Status} = "charging"}
            49 {$this.{running Status} = "charging completed"}
            50 {$this.{running Status} = "discharging"}
        }

        switch ($bbu.TYPE)
        {
            210 {$this.{PSU Type} = "BBU"}
        }
        $this.{voltage} = $bbu.VOLTAGE / 10
    }
}