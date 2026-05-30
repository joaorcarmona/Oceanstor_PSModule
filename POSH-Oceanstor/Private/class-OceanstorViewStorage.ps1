class OceanstorViewStorage{
	hidden [pscustomobject]${Session}
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
		$storageConnection = Connect-deviceManager -Hostname $Hostname -Return $true -Secure

		$this.Session = $storageConnection
		$this.Hostname = $Hostname
		$this.System = Get-DMSystem -WebSession $storageConnection
		$this.Luns = Get-DMluns -WebSession $storageConnection
		$this.LunGroups = Get-DMlunGroups -WebSession $storageConnection
		$this.disks = Get-DMdisks -WebSession $storageConnection
		$this.Hosts = Get-DMhosts -WebSession $storageConnection
		$this.HostGroups = Get-DMhostGroups -WebSession $storageConnection
		$this.StoragePools = Get-DMstoragePools -WebSession $storageConnection
		$this.DeviceId = $this.System.sn
		$this.vStores = Get-DMvStore -WebSession $storageConnection
		$this.{FileSystems} = Get-DMFileSystem -WebSession $storageConnection
		$this.{CIFS Shares} = Get-DMShares -WebSession $storageConnection -shareType CIFS
		$this.{NFS Shares} = Get-DMShares -WebSession $storageConnection -shareType NFS
		$this.{Active Alarms} = Get-DMAlarms -webSession $storageConnection -AlarmStatus "Unrecovered"
		$this.Enclosures = Get-DMEnclosures -WebSession $storageConnection
		$this.Controllers = Get-DMControllers -WebSession $storageConnection
		$this.InterfaceModules = Get-DMInterfaceModules -WebSession $storageConnection
    }
}
