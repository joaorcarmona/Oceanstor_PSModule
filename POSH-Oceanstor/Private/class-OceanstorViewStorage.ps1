class OceanstorViewStorage{
	hidden [pscustomobject]${Session}
	hidden [pscustomobject]${WebSession}
	#Define Hostname Property
	[string]$Hostname

	#Define DeviceID Property
	[string]$DeviceId

	#define System Array
	[PSCustomObject]$System

	#Define System Configuration
	[PSCustomObject]$NtpServer

	[PSCustomObject]$NtpStatus

	[PSCustomObject]$SnmpConfig

	[PSCustomObject]$SnmpSecurityPolicy

	[array]$SnmpTrapServers

	[array]$SnmpUsmUsers

	[PSCustomObject]$SyslogNotification

	[array]$LocalUsers

	[array]$Roles

	[array]$RolePermissions

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
		$storageConnection = Connect-deviceManager -Hostname $Hostname -PassThru -Secure

		$this.Session = $storageConnection
		$this.WebSession = $storageConnection
		$this.Hostname = $Hostname
		$this.System = Get-DMSystem -WebSession $storageConnection
		$this.NtpServer = Get-DMNtpServer -WebSession $storageConnection
		$this.NtpStatus = Get-DMNtpStatus -WebSession $storageConnection
		$this.SnmpConfig = Get-DMSnmpConfig -WebSession $storageConnection
		$this.SnmpSecurityPolicy = Get-DMSnmpSecurityPolicy -WebSession $storageConnection
		$this.SnmpTrapServers = Get-DMSnmpTrapServer -WebSession $storageConnection
		$this.SnmpUsmUsers = Get-DMSnmpUsmUser -WebSession $storageConnection
		$this.SyslogNotification = Get-DMSyslogNotification -WebSession $storageConnection
		$this.LocalUsers = Get-DMLocalUser -WebSession $storageConnection
		$this.Roles = Get-DMRole -WebSession $storageConnection
		$this.RolePermissions = Get-DMRolePermission -WebSession $storageConnection -RoleOwnerGroup '1'
		$this.Luns = Get-DMlun -WebSession $storageConnection
		$this.LunGroups = Get-DMlunGroup -WebSession $storageConnection
		$this.disks = Get-DMdisk -WebSession $storageConnection
		$this.Hosts = Get-DMhost -WebSession $storageConnection
		$this.HostGroups = Get-DMhostGroup -WebSession $storageConnection
		$this.StoragePools = Get-DMstoragePool -WebSession $storageConnection
		$this.DeviceId = $this.System.sn
		$this.vStores = Get-DMvStore -WebSession $storageConnection
		$this.{FileSystems} = Get-DMFileSystem -WebSession $storageConnection
		$this.{CIFS Shares} = Get-DMShare -WebSession $storageConnection -shareType CIFS
		$this.{NFS Shares} = Get-DMShare -WebSession $storageConnection -shareType NFS
		$this.{Active Alarms} = Get-DMAlarm -webSession $storageConnection -AlarmStatus "Unrecovered"
		$this.Enclosures = Get-DMEnclosure -WebSession $storageConnection
		$this.Controllers = Get-DMController -WebSession $storageConnection
		$this.InterfaceModules = Get-DMInterfaceModule -WebSession $storageConnection
    }
}

