class OceanstorStorage{
	#Define Hostname Property
	[string]$Hostname

	#Define DeviceID Property
	[string]$DeviceId

	#define System Array
	[OceanStorSystem]$System

	#Define Alarm Count
	[int64]${Active Alarms}

	#Define vStore Count
	[int64]${Number of vStores}

	#define Luns
	[array]$Luns

	#Define Disk
	[array]$disks

	#Define LunGroups
	[array]$LunGroups

	#Define Hosts
	[array]$Hosts

	#Define Host Groups
	[array]$HostGroups

	#Define Storage Pools
	[array]$StoragePools

	#Define vStores
	[array]$vStores

    # Constructor
    OceanstorStorage ([String] $Hostname)
    {
		$storageConnection = connect-deviceManager -Hostname $Hostname -Return $true

		$this.Hostname = $Hostname
		$this.System = get-DMSystem -WebSession $storageConnection
		$this.Luns = get-DMluns -WebSession $storageConnection
		$this.LunGroups = get-DMlunGroups -WebSession $storageConnection
		$this.disks = get-DMdisks -WebSession $storageConnection
		$this.Hosts = get-DMhosts -WebSession $storageConnection
		$this.HostGroups = get-DMhostGroups -WebSession $storageConnection
		$this.StoragePools = get-DMstoragePools -WebSession $storageConnection
		$this.DeviceId = $this.System.sn
		$this.vStores = get-DMvStore -WebSession $storageConnection
    }
}