class OceanStorSystem{
	#Define Properties
	[string]$sn
	[string]$version
	[string]$WWN
	[string]$location
	[string]$description
	[string]${Health Status}
	[string]${Running Status}
	[int]$HotSpareNumbers

	OceanStorSystem ([array]$systemArray)
	{
		$SystemProperties = @{}

		foreach ($line in $systemArray)
		{

			$sysprop = $line.split("=")
			$key = $sysprop[0]
			$value = $sysprop[1]
			$SystemProperties.add($key.trim(), $value)
		}
		$this.sn = $SystemProperties["ID"]
		$sysProductVersion = $SystemProperties.PRODUCTVERSION
		$this.version = $sysProductVersion
		$this.WWN = $SystemProperties["wwn"]
		$this.location = $SystemProperties["LOCATION"]
		$sysDescription = $SystemProperties.DESCRIPTION
		$this.description = $sysDescription

		switch($SystemProperties.HEALTHSTATUS)
		{
			1 {$this.{Health Status} = "Normal"}
			2 {$this.{Health Status} = "Faulty"}
		}

		switch($SystemProperties.RUNNINGSTATUS)
		{
			1 {$this.{Running Status} = "Normal"}
			3 {$this.{Running Status} = "Not Running"}
			12 {$this.{Running Status} = "Powering on"}
			47 {$this.{Running Status} = "Powering off"}
			51 {$this.{Running Status} = "Upgrading"}
		}

		$this.HotSpareNumbers = $SystemProperties["HOTSPAREDISKSCAPACITY"]
	}
}