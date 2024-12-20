class OceanstorViewStorage{
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

	#Define Enclosures
	[array]$Enclosures

	#Define Controllers
	[array]$Controllers

	#Define Interface Modules
	[array]$InterfaceModules

    # Constructor
    OceanstorViewStorage ([String] $Hostname)
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
		$this.{CIFS Shares} = get-DMShares -WebSession $storageConnection -shareType CIFS
		$this.{NFS Shares} = get-DMShares -WebSession $storageConnection -shareType NFS
		$this.{Active Alarms} = get-DMAlarms -webSession $storageConnection -AlarmStatus "Unrecovered"
		$this.Enclosures = get-DMEnclosures -WebSession $storageConnection
		$this.Controllers = get-DMControllers -WebSession $storageConnection
		$this.InterfaceModules = get-DMInterfaceModules -WebSession $storageConnection
    }
}