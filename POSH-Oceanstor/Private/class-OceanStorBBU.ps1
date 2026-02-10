class OceanStorBBU
{
    [string]${Id}
    [string]${Parent Id}
    [string]${Parent Type}
    [string]${Controller Id}
    [string]${PSU Location}
    [string]${name}
    [string]${Manufacter Date}
    [string]${Charge Times}
    [string]${Description}
    [string]${Firmware Version}
    [string]${Health Status}
    [string]${Remaining Life}
    [string]${running Status}
    [string]${PSU Type}
    [string]${voltage}

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
        $this.{Manufacter Date} = $bbu.MANUFACTUREDATE
        $this.{Charge Times} = $bbu.CHARGETIMES
        $this.{Description} = $bbu.DESCRIPTION
        $this.{Firmware Version} = $bbu.FIRMWAREVERSION

        switch ($bbu.healthstatus)
        {
            0 {$this.{Health Status} = "unknown"}
            1 {$this.{Health Status} = "normal"}
            2 {$this.{Health Status} = "faulty"}
            3 {$this.{Health Status} = "about to fail"}
            12 {$this.{Health Status} = "low battery"}
        }

        $this.{Remaining Life} = $bbu.REMAININGLIFE

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
        $this.{voltage} = $bbu.VOLTAGE
    }
}