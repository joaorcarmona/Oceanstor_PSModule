class OceanstorStorage{
	#Define Hostname Property
	[string]$Hostname

	#Define DeviceID Property
	[string]$DeviceId

	#define System Array
	[PSCustomObject]$System

	#TODO
	#Define Alarm Count
	#[int64]${Number of Alarms}

	#Define vStore Count
	#[int64]${Number of vStores}

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

	#Define File Systems
	[array]$FileSystems

	#Define CIFS Shares
	[array]${CIFS Shares}

	#Define NFS Shares
	[array]${NFS Shares}

	#Define Active Alarms
	[array]${Active Alarms}

    # Constructor
    OceanstorStorage ([String] $Hostname)
    {
		$storageConnection = connect-deviceManager -Hostname $Hostname -Return $true -Secure

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
		$this.{FileSystems} = get-DMFileSystem -WebSession $storageConnection
		$this.{CIFS Shares} = get-DMCifsShare -WebSession $storageConnection
		$this.{NFS Shares} = get-DMNfsShare -WebSession $storageConnection
		$this.{Active Alarms} = get-DMAlarms -webSession $storageConnection -AlarmStatus "Unrecovered"
    }
}