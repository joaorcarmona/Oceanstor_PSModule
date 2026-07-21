class OceanStorSystem{
	hidden [pscustomobject]${Session}
	hidden [pscustomobject]${WebSession}
	#Define Properties
	[string]$sn
	[string]$version
	[string]$WWN
	[string]$location
	[string]$description
	[string]${Health Status}
	[string]${Running Status}
	# Raw total capacity of all hot-spare disks (HOTSPAREDISKSCAPACITY, uint64).
	# Widened from [int] to [int64] so real-array sector counts do not overflow.
	[int64]$HotSpareNumbers

	OceanStorSystem ([array]$systemArray, [pscustomobject]$WebSession)
	{
		$this.Session = $WebSession
		$this.WebSession = $WebSession
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


