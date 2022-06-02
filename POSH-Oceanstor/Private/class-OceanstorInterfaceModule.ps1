class OceanstorInterfaceModule
{
    #Define Properties
    [string]${Id}
    [string]${Name}
    [string]${Type}
    [string]${Board Type}
    [string]${Bar Code}
    [string]${Part Number}
    [string]${Description}
    [string]$Manufactured
    [string]${Vendor Name}
    [string]${Health Status}
    [string]${Light Status}
    [string]${Location}
    [string]${Logic Version}
    [string]${Model}
    [string]${Multi-Working Mode}
    [string]${Enclosure Id}
    [string]${PCB Version}
    [string]${Operating Mode}
    [string]${runmodelist}
    [string]${Running Status}
    [string]${Temperature}

    OceanstorInterfaceModule ([array]$moduleReceived)
    {
        $this.{Health Status} = $moduleReceived.HEALTHSTATUS

        switch($moduleReceived.HEALTHSTATUS)
		{
			0 {$this.{Health Status} = "unknown"}
			1 {$this.{Health Status} = "normal"}
			2 {$this.{Health Status} = "faulty"}
		}

        $this.{Id} = $moduleReceived.ID
        $this.{Light Status} = $moduleReceived.LIGHTSTATUS
        $this.{Location} = $moduleReceived.LOCATION
        $this.{Logic Version} = $moduleReceived.LOGICVER

        switch ($moduleReceived.MODEL)
        {
            6 {$this.{Model} = "2x10GE Optical Interface Module"}
            12 {$this.{Model} = "4xGE Electrical Interface Module"}
            13 {$this.{Model} = "4x8G FC Optical Interface Module"}
            21 {$this.{Model} = "4x10G FCoE Optical Interface Module"}
            24 {$this.{Model} = "Management Board"}
            25 {$this.{Model} = "4x10GE Interface Module"}
            26 {$this.{Model} = "PCIe Interface Module"}
            29 {$this.{Model} = "2x16G FC Optical Interface Module"}
            30 {$this.{Model} = "4x12G SAS QSFP Interface Module"}
            31 {$this.{Model} = "4x10GE Electrical Interface Module"}
            33 {$this.{Model} = "2-port 4x14G IB I/O Module"}
            35 {$this.{Model} = "Smart ACC Module"}
            36 {$this.{Model} = "4x10GE Electrical Interface Module"}
            37 {$this.{Model} = "4-port SmartIO I/O Module"}
            38 {$this.{Model} = "8x8G FC Optical Interface Module"}
            49 {$this.{Model} = "4x16G FC Optical Interface Module"}
            41 {$this.{Model} = "12-port 4x12G SAS Back-End Interconnect I/O Module"}
            44 {$this.{Model} = "2-port PCIe 3.0 Interface Module"}
            58 {$this.{Model} = "8x16G FC Optical Interface Module"}
            65 {$this.{Model} = "4 ports SmartIO I/O module"}
            66 {$this.{Model} = "4 ports SmartIO I/O module"}
            67 {$this.{Model} = "2 ports 100Gb/40Gb ETH I/O module"}
            68 {$this.{Model} = "2 ports 100Gb/40Gb ETH I/O module"}
            71 {$this.{Model} = "4 ports 10Gb ETH I/O module"}
            516 {$this.{Model} = "4 ports FE 1 Gbit/s ETH I/O module"}
            518 {$this.{Model} = "4 ports BE 12 Gbit/s SAS I/O module"}
            529 {$this.{Model} = "AI Accelerator Card"}
            535 {$this.{Model} = "AI Accelerator Card"}
            537 {$this.{Model} = "4 ports FE 1 Gbit/s ETH I/O module"}
            538 {$this.{Model} = "4 ports BE 12 Gbit/s SAS I/O module"}
            580 {$this.{Model} = "4 ports FE 1 Gbit/s ETH I/O module"}
            583 {$this.{Model} = "4 ports BE 12 Gbit/s SAS V2 I/O module"}
            601 {$this.{Model} = "4 ports FE 1 Gbit/s ETH I/O module"}
            2304 {$this.{Model} = "4 ports FE 8 Gbit/s Fibre Channel I/O module"}
            2305 {$this.{Model} = "4 ports FE 16 Gbit/s Fibre Channel I/O module"}
            2306 {$this.{Model} = "4 ports FE 32 Gbit/s Fibre Channel I/O module"}
            2307 {$this.{Model} = "4 ports FE 10 Gbit/s ETH I/O module"}
            2308 {$this.{Model} = "4 ports FE 25 Gbit/s ETH I/O module"}
            2309 {$this.{Model} = "4 ports SO 25 Gbit/s RDMA I/O module"}
            2310 {$this.{Model} = "4 ports FE 8 Gbit/s Fibre Channel I/O module"}
            2311 {$this.{Model} = "4 ports FE 16 Gbit/s Fibre Channel I/O module"}
            2312 {$this.{Model} = "4 ports FE 32 Gbit/s Fibre Channel I/O module"}
            2313 {$this.{Model} = "4 ports FE 10 Gbit/s ETH I/O module"}
            2314 {$this.{Model} = "4 ports FE 25 Gbit/s ETH I/O module"}
            2315 {$this.{Model} = "2 ports FE 40 Gbit/s ETH I/O module"}
            2316 {$this.{Model} = "2 ports FE 100 Gbit/s ETH I/O module"}
            2317 {$this.{Model} = "2 ports BE 100 Gbit/s RDMA I/O module"}
            2318 {$this.{Model} = "2 ports SO 100 Gbit/s RDMA I/O module"}
            2319 {$this.{Model} = "2 ports FE 40 Gbit/s ETH I/O module"}
            2320 {$this.{Model} = "2 ports FE 100 Gbit/s ETH I/O module"}
            2321 {$this.{Model} = "2 ports BE 100 Gbit/s RDMA I/O module"}
            2322 {$this.{Model} = "2 ports SO 100 Gbit/s RDMA I/O module"}
            2323 {$this.{Model} = "4 ports FE 10 Gbit/s ROCE I/O module"}
            2324 {$this.{Model} = "4 ports FE 25 Gbit/s ROCE I/O module"}
            2325 {$this.{Model} = "4 ports FE 10 Gbit/s ROCE I/O module"}
            2326 {$this.{Model} = "4 ports FE 25 Gbit/s ROCE I/O module"}
            2327 {$this.{Model} = "2 ports FE 40 Gbit/s ROCE I/O module"}
            2328 {$this.{Model} = "2 ports FE 100 Gbit/s ROCE I/O module"}
            2329 {$this.{Model} = "2 ports FE 40 Gbit/s ROCE I/O module"}
            2330 {$this.{Model} = "2 ports FE 100 Gbit/s ROCE I/O module"}
            2331 {$this.{Model} = "4 ports FE 10 Gbit/s ETH I/O module"}
            2332 {$this.{Model} = "4 ports FE 10 Gbit/s ETH I/O module"}
            2333 {$this.{Model} = "4 ports FE 8 Gbit/s Fibre Channel I/O module"}
            2334 {$this.{Model} = "4 ports FE 16 Gbit/s Fibre Channel I/O module"}
            2335 {$this.{Model} = "4 ports FE 32 Gbit/s Fibre Channel I/O module"}
            2336 {$this.{Model} = "4 ports FE 10 Gbit/s ETH I/O module"}
            2337 {$this.{Model} = "4 ports FE 25 Gbit/s ETH I/O module"}
            2338 {$this.{Model} = "4 ports SO 25 Gbit/s RDMA I/O module"}
            2339 {$this.{Model} = "4 ports FE 10 Gbit/s ROCE I/O module"}
            2340 {$this.{Model} = "4 ports FE 25 Gbit/s ROCE I/O module"}
            2341 {$this.{Model} = "4 ports FE 8 Gbit/s Fibre Channel I/O module"}
            2342 {$this.{Model} = "4 ports FE 16 Gbit/s Fibre Channel I/O module"}
            2343 {$this.{Model} = "4 ports FE 32 Gbit/s Fibre Channel I/O module"}
            2344 {$this.{Model} = "4 ports FE 10 Gbit/s ETH I/O module"}
            2345 {$this.{Model} = "4 ports FE 25 Gbit/s ETH I/O module"}
            2346 {$this.{Model} = "4 ports FE 10 Gbit/s ROCE I/O module"}
            2347 {$this.{Model} = "4 ports FE 25 Gbit/s ROCE I/O module"}
            2348 {$this.{Model} = "2 ports FE 40 Gbit/s ETH I/O module"}
            2349 {$this.{Model} = "2 ports FE 100 Gbit/s ETH I/O module"}
            2350 {$this.{Model} = "2 ports BE 100 Gbit/s RDMA I/O module"}
            2351 {$this.{Model} = "2 ports SO 100 Gbit/s RDMA I/O module"}
            2352 {$this.{Model} = "2 ports FE 40 Gbit/s ROCE I/O module"}
            2353 {$this.{Model} = "2 ports FE 100 Gbit/s ROCE I/O module"}
            2354 {$this.{Model} = "2 ports FE 40 Gbit/s ETH I/O module"}
            2355 {$this.{Model} = "2 ports FE 100 Gbit/s ETH I/O module"}
            2356 {$this.{Model} = "2 ports BE 100 Gbit/s RDMA I/O module"}
            2357 {$this.{Model} = "2 ports SO 100 Gbit/s RDMA I/O module"}
            2358 {$this.{Model} = "2 ports FE 40 Gbit/s ROCE I/O module"}
            2359 {$this.{Model} = "2 ports FE 100 Gbit/s ROCE I/O module"}
            2360 {$this.{Model} = "4 ports FE 10 Gbit/s ETH I/O module"}
            2361 {$this.{Model} = "4 ports SO 25 Gbit/s RDMA I/O module"}
            2362 {$this.{Model} = "2 ports SO 100 Gbit/s RDMA I/O module"}
            2363 {$this.{Model} = "2 ports SO 100 Gbit/s RDMA I/O module"}
            4133 {$this.{Model} = "System Management Module"}
            4134 {$this.{Model} = "System Management Module"}
            default {$this.{Model} = "unknown"}
        }

        switch($moduleReceived.MULTMODE)
		{
			true {$this.{Multi-Working Mode} = "supported"}
			false {$this.{Multi-Working Mode} = "not supported"}
        }

        $this.{Name} = $moduleReceived.NAME
        $this.{Enclosure Id} = $moduleReceived.PARENTID
        $this.{PCB Version} = $moduleReceived.PCBVER

        switch($moduleReceived.RUNMODE)
		{
			1 {$this.{Operating Mode} = "Fibre Channel"}
			2 {$this.{Operating Mode} = "Ethernet (FCoE/iSCSI)"}
            3 {$this.{Operating Mode} = "cluster"}
        }

        $this.{runmodelist} = $moduleReceived.RUNMODELIST

        switch($moduleReceived.RUNNINGSTATUS)
		{
			0 {$this.{Running Status} = "unknown"}
			1 {$this.{Running Status} = "normal"}
			2 {$this.{Running Status} = "running"}
            12 {$this.{Running Status} = "powering on"}
            23 {$this.{Running Status} = "powering off"}
            21 {$this.{Running Status} = "online"}
            28 {$this.{Running Status} = "offline"}
            104 {$this.{Running Status} = "power-on failed"}
		}

        $this.{Temperature} = $moduleReceived.TEMPERATURE
        switch($moduleReceived.TYPE)
		{
			209 {$this.{Type} = "Interface Module"}
		}

        $labels =  get-DMparsedElabel -eLabelString $moduleReceived.ELABEL
        $this.{Board Type} = $labels.BoardType
        $this.{Bar Code} = $labels.BarCode
        $this.{Part Number} = $labels.Item
        $this.{Description} = $labels.Description
        $this.Manufactured = $labels.Manufactured
        $this.{Vendor Name} = $labels.VendorName
    }
}