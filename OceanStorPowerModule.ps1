#Define Trust Certificate
add-type @"
		using System.Net;
		using System.Security.Cryptography.X509Certificates;
		public class TrustAllCertsPolicy : ICertificatePolicy {
		public bool CheckValidationResult(
		ServicePoint srvPoint, X509Certificate certificate,
		WebRequest request, int certificateProblem) {
		return true;
	}
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy


#Define Object Class
class OceanStorSystem
{
	#Position 2
	[string]$description
	#Position 5 TODO
	#[int64] $Health
	#Position 6
	[int]$HotSpareNumbers
	#Position 8
	[string]$location
	#Position 12
	[string]$version
	#Position 40
	[string]$WWN
	#Define SN
	[string]$sn

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

		$sysDescription = $SystemProperties.DESCRIPTION
		$this.description = $sysDescription
		$this.HotSpareNumbers = $SystemProperties["HOTSPAREDISKSCAPACITY"]
		$this.sn = $SystemProperties["ID"]
		$this.location = $SystemProperties["LOCATION"]
		$sysProductVersion = $SystemProperties.PRODUCTVERSION
		$this.version = $sysProductVersion
		$this.WWN = $SystemProperties["wwn"]
	}
}

class OceanstorDeviceLun
{
	#Define Lun ID (id)
	[Int]$id

	#Define Lun Name (name)
	[string]$name

	#Define Lun Type (ALLOCTYPE)
	[string]$type

	#Define wwn
	[string]$wwn

	#define Lun Health Status
	[string]$health

	#define Lun Running Status
	[string]$runningStatus

	#Define StoragePoolID
	[Int]$StoragePoolId

	#Define StoragePoolName (PARENTID)
	[string]$StoragePool

	#Define Description
	[string]$description

	#define SpaceAlocated (capacity)
	[Int64]$Size

	#define SpaceUsed (alloccapacity)
	[Int64]$SpaceUsed

	#define
	[string]$owningController

	#define
	[string]$runningController

	#Define Dedupe Variables
	[boolean]$dedupeEnabled
	[int64]$dedupeSavedCapacity
	[int64]$dedupeSavedRatio

	#Define Compression
	[boolean]$compressionEnabled
	[int64]$compressionSavedCapacity
	[int64]$compressionSavedRatio

	#Define SavedCpacity
	[int64]$totalsavedcapacity
	[int64]$totalsavedratio

	[int64]$SpaceBeforeSaving

	OceanstorDeviceLun ([array]$LunReceived)
	{
		$lunID = $LunReceived.ID
		$this.id = $lunID

		$lunName = $LunReceived.NAME
		$this.name = $LunName

		$LunALLOCTYPE = $LunReceived.ALLOCTYPE
		switch ($LunALLOCTYPE)
		{
			0 {$this.type = "Thick"}
			1 {$this.type = "Thin"}
		}

		$LunWWN = $LunReceived.WWN
		$this.wwn = $LunWWN

		switch($LunReceived.HEALTHSTATUS)
		{
			1 {$this.health = "Normal"}
			2 {$this.health = "Faulty"}
		}

		switch($LunReceived.RUNNINGSTATUS)
		{
			27 {$this.runningStatus = "Online"}
			28 {$this.runningStatus = "Offline"}
			53 {$this.runningStatus = "Initializing"}
		}

		$this.StoragePoolId = $LunReceived.PARENTID
		$this.StoragePool = $LunReceived.PARENTNAME

		[int64]$LunSectorSize = $LunReceived.SECTORSIZE
		[int64]$LunCapacity = $LunReceived.CAPACITY
		[int64]$LunSize = $LunCapacity * $LunSectorSize / 1GB
		$this.Size = $LunSize

		[int64]$lunAllocCapacity = $LunReceived.ALLOCCAPACITY
		$LunSpaceUsed = $lunAllocCapacity * $LunSectorSize / 1GB
		$this.SpaceUsed = $LunSpaceUsed

		$this.owningController = $LunReceived.OWNINGCONTROLLER
		$this.runningController = $LunReceived.WORKINGCONTROLLER

		if ($LunReceived.ENABLEDEDUP -eq "FALSE")
		{
			$this.dedupeEnabled = $false
		} elseif ($LunReceived.ENABLEDEDUP -eq "TRUE")
		{
			$this.dedupeEnabled = $true
		}

		$this.dedupeSavedCapacity = $LunReceived.DEDUPSAVEDCAPACITY * $LunSectorSize / 1GB
		$this.dedupeSavedRatio = $LunReceived.DEDUPSAVEDRATIO

		if ($LunReceived.ENABLECOMPRESSION -eq "FALSE")
		{
			$this.compressionEnabled = $false
		} elseif ($LunReceived.ENABLECOMPRESSION -eq "TRUE")
		{
			$this.compressionEnabled = $true
		}

		$this.compressionSavedCapacity = $LunReceived.COMPRESSIONSAVEDCAPACITY * $LunSectorSize / 1GB
		$this.compressionSavedRatio = $LunReceived.COMPRESSIONSAVEDRATIO

		$this.totalsavedcapacity = $LunReceived.TOTALSAVEDCAPACITY * $LunSectorSize / 1GB
		$this.totalsavedratio = $LunReceived.TOTALSAVEDRATIO
		$this.SpaceBeforeSaving = $LunReceived.SAVEDAGOTOTALCAPACITY * $LunSectorSize / 1GB

	}
}

class OceanStorLunGroup
{
	#Define Properties
	[int]${LunGroup ID}
	[string]${LunGroup Name}
	[string]$Description
	[string]${Application Type}
	[string]${LunGroup Type}
	[string]${LunGroup Capacity}
	[string]${Application Configuration Data}
	[int]${vStore ID}
	[string]${vStore Name}
	[boolean]${Is Mapped}

	OceanStorLunGroup ([array]$LunGroupReceived)
	{
		$this.{LunGroup ID} = $LunGroupReceived.ID
		$this.{LunGroup Name} = $LunGroupReceived.NAME
		$this.Description = $LunGroupReceived.DESCRIPTION
		$this.{Application Type} = $LunGroupReceived.APPTYPE
		$this.{LunGroup Type} = $LunGroupReceived.GROUPTYPE
		$this.{LunGroup Capacity} = $LunGroupReceived.CAPCITY
		$this.{Application Configuration Data} = $LunGroupReceived.CONFIGDATA
		$this.{vStore ID} = $LunGroupReceived.vstoreid
		$this.{vStore Name} = $LunGroupReceived.vstoreName

		if ($LunGroupReceived.ISADD2MAPPINGVIEW -eq "false")
		{
			$this.{Is Mapped} = $false
		} elseif ($LunGroupReceived.ISADD2MAPPINGVIEW -eq "true") {
			$this.{Is Mapped} = $true
		}
	}
}

class OceanStorHostGroup
{
	#Define Properties
	[int]${HostGroup ID}
	[string]${HostGroup Name}
	[string]$Description
	[string]${HostGroup Type}
	[int]${vStore ID}
	[string]${vStore Name}
	[boolean]${Is Mapped}

	OceanStorHostGroup ([array]$HostGroupReceived)
	{
		$this.{HostGroup ID} = $HostGroupReceived.ID
		$this.{HostGroup Name} = $HostGroupReceived.NAME
		$this.Description = $HostGroupReceived.DESCRIPTION
		$this.{HostGroup Type} = $HostGroupReceived.TYPE
		$this.{vStore ID} = $HostGroupReceived.vstoreid
		$this.{vStore Name} = $HostGroupReceived.vstoreName

		if ($HostGroupReceived.ISADD2MAPPINGVIEW -eq "false")
		{
			$this.{Is Mapped} = $false
		} elseif ($HostGroupReceived.ISADD2MAPPINGVIEW -eq "true") {
			$this.{Is Mapped} = $true
		}
	}
}

class OceanStorStoragePool
{
	#TODO DEFINE Properties with friendly Name & complete information
	#Define Properties
	[string]$autodeactivesnapshotswitch
	[string]$dataspace
	[string]$description
	[string]$dstrunningstatus
	[string]$dststatus
	[string]$enablesmartcache
	[string]$enablessdbuffer
	[string]$extentsize
	[string]$healthstatus
	[string]$id
	[string]$immediatemigration
	[string]$immediatemigrationdurationtime
	[string]$issmarttierenable
	[string]$lunconfigedcapacity
	[string]$migrationestimatedtime
	[string]$migrationmode
	[string]$migrationscheduleid
	[string]$monitorscheduleid
	[string]$moveddowndata
	[string]$movedowndata
	[string]$movedupdata
	[string]$moveupdata
	[string]$name
	[string]$parentid
	[string]$parentname
	[string]$pausemigrationswitch
	[string]$repcapacitythreshold
	[string]$replicationcapacity
	[string]$reservedcapacity
	[string]$runningstatus
	[string]$tier0capacity
	[string]$tier0disktype
	[string]$tier0raiddisknum
	[string]$tier0raidlv
	[string]$tier0stripedepth
	[string]$tier1capacity
	[string]$tier1disktype
	[string]$tier1raiddisknum
	[string]$tier1raidlv
	[string]$tier1stripedepth
	[string]$tier2capacity
	[string]$tier2disktype
	[string]$tier2raiddisknum
	[string]$tier2raidlv
	[string]$tier2stripedepth
	[string]$totalfscapacity
	[string]$type
	[string]$usagetype
	[string]$userconsumedcapacity
	[string]$userconsumedcapacitypercentage
	[string]$userconsumedcapacitythreshold
	[string]$userfreecapacity
	[string]$usertotalcapacity
	[string]$compressratio
	[string]$compressedcapacity
	[string]$dedupcompressratio
	[string]$dedupratio
	[string]$dedupedcapacity
	[string]$reductioninvolvedcapacity

	OceanStorStoragePool ([array]$spoolReceived)
	{
		$this.autodeactivesnapshotswitch = $spoolReceived.AUTODEACTIVESNAPSHOTSWITCH
		$this.dataspace = $spoolReceived.DATASPACE
		$this.description = $spoolReceived.DESCRIPTION
		$this.dstrunningstatus = $spoolReceived.DSTRUNNINGSTATUS
		$this.dststatus = $spoolReceived.DSTSTATUS
		$this.enablesmartcache = $spoolReceived.ENABLESMARTCACHE
		$this.enablessdbuffer = $spoolReceived.ENABLESSDBUFFER
		$this.extentsize = $spoolReceived.EXTENTSIZE
		$this.healthstatus = $spoolReceived.HEALTHSTATUS
		$this.id = $spoolReceived.ID
		$this.immediatemigration = $spoolReceived.IMMEDIATEMIGRATION
		$this.immediatemigrationdurationtime = $spoolReceived.IMMEDIATEMIGRATIONDURATIONTIME
		$this.issmarttierenable = $spoolReceived.ISSMARTTIERENABLE
		$this.lunconfigedcapacity = $spoolReceived.LUNCONFIGEDCAPACITY
		$this.migrationestimatedtime = $spoolReceived.MIGRATIONESTIMATEDTIME
		$this.migrationmode = $spoolReceived.MIGRATIONMODE
		$this.migrationscheduleid = $spoolReceived.MIGRATIONSCHEDULEID
		$this.monitorscheduleid = $spoolReceived.MONITORSCHEDULEID
		$this.moveddowndata = $spoolReceived.MOVEDDOWNDATA
		$this.movedowndata = $spoolReceived.MOVEDOWNDATA
		$this.movedupdata = $spoolReceived.MOVEDUPDATA
		$this.moveupdata = $spoolReceived.MOVEUPDATA
		$this.name = $spoolReceived.NAME
		$this.parentid = $spoolReceived.PARENTID
		$this.parentname = $spoolReceived.PARENTNAME
		$this.pausemigrationswitch = $spoolReceived.PAUSEMIGRATIONSWITCH
		$this.repcapacitythreshold = $spoolReceived.REPCAPACITYTHRESHOLD
		$this.replicationcapacity = $spoolReceived.REPLICATIONCAPACITY
		$this.reservedcapacity = $spoolReceived.RESERVEDCAPACITY
		$this.runningstatus = $spoolReceived.RUNNINGSTATUS
		$this.tier0capacity = $spoolReceived.TIER0CAPACITY
		$this.tier0disktype = $spoolReceived.TIER0DISKTYPE
		$this.tier0raiddisknum = $spoolReceived.TIER0RAIDDISKNUM
		$this.tier0raidlv = $spoolReceived.TIER0RAIDLV
		$this.tier0stripedepth = $spoolReceived.TIER0STRIPEDEPTH
		$this.tier1capacity = $spoolReceived.TIER1CAPACITY
		$this.tier1disktype = $spoolReceived.TIER1DISKTYPE
		$this.tier1raiddisknum = $spoolReceived.TIER1RAIDDISKNUM
		$this.tier1raidlv = $spoolReceived.TIER1RAIDLV
		$this.tier1stripedepth = $spoolReceived.TIER1STRIPEDEPTH
		$this.tier2capacity = $spoolReceived.TIER2CAPACITY
		$this.tier2disktype = $spoolReceived.TIER2DISKTYPE
		$this.tier2raiddisknum = $spoolReceived.TIER2RAIDDISKNUM
		$this.tier2raidlv = $spoolReceived.TIER2RAIDLV
		$this.tier2stripedepth = $spoolReceived.TIER2STRIPEDEPTH
		$this.totalfscapacity = $spoolReceived.TOTALFSCAPACITY
		$this.type = $spoolReceived.TYPE
		$this.usagetype = $spoolReceived.USAGETYPE
		$this.userconsumedcapacity = $spoolReceived.USERCONSUMEDCAPACITY
		$this.userconsumedcapacitypercentage = $spoolReceived.USERCONSUMEDCAPACITYPERCENTAGE
		$this.userconsumedcapacitythreshold = $spoolReceived.USERCONSUMEDCAPACITYTHRESHOLD
		$this.userfreecapacity = $spoolReceived.USERFREECAPACITY
		$this.usertotalcapacity = $spoolReceived.USERTOTALCAPACITY
		$this.compressratio = $spoolReceived.compressRatio
		$this.compressedcapacity = $spoolReceived.compressedCapacity
		$this.dedupcompressratio = $spoolReceived.dedupCompressRatio
		$this.dedupratio = $spoolReceived.dedupRatio
		$this.dedupedcapacity = $spoolReceived.dedupedCapacity
		$this.reductioninvolvedcapacity = $spoolReceived.reductionInvolvedCapacity
	}
}

class OceanStorDisks
{
	#Define Variables
	[string]$encryptDiskType
	[string]$firmwareVersion
	[string]$healthMark
	[string]$healthStatus
	[string]$id
	[boolean]$cofferDisk
	[string]$partNumber
	[string]$keyExpirationTime
	[string]$lightStatus
	[string]$location
	[string]$logicType
	[string]$manufacter
	[string]$model
	[string]$multipath
	[string]$parentId
	[string]${parent Type}
	[string]$poolId
	[string]$poolName
	[string]$poolTierId
	[string]$progress
	[string]$remainLife
	[string]$runningStatus
	[string]$runtime
	[string]$sectors
	[string]$sectorSize
	[string]$serialNumber
	[string]$smartCachePoolId
	[string]$speedRPM
	[string]$storeEngineId
	[string]$temperature
	[string]$type
	[string]$barCode
	[string]$formartProgress
	[string]$formatRemainTime
	[string]$manufacterCapacity

	OceanStorDisks ([array]$disks)
	{
		$this.encryptDiskType = $disks.ENCRYPTDISKTYPE
		$this.firmwareVersion = $disks.FIRMWAREVER
		$this.healthMark = $disks.HEALTHMARK

		switch($disks.HEALTHSTATUS)
		{
			0 {$this.healthStatus = "Unknown"}
			1 {$this.healthStatus = "Normal"}
			2 {$this.healthStatus = "Faulty"}
			3 {$this.healthStatus = "about to fail"}
		}

		$this.id = $disks.ID

		if ($disks.ISCOFFERDISK -eq "FALSE")
		{
			$this.cofferDisk = $false
		} elseif ($disks.ISCOFFERDISK -eq "TRUE")
		{
			$this.cofferDisk = $true
		}

		#$this.item = $disks.ITEM TO be solve for now using alternative way to get partNumber
		$this.partNumber = $($disks.barcode.Substring(0,10)).Substring(2)
		$this.keyExpirationTime = $disks.KEYEXPIRATIONTIME

		switch($disks.LIGHTSTATUS)
		{
			0 {$this.lightStatus = "off"}
			1 {$this.lightStatus = "blinking"}
			2 {$this.lightStatus = "steady on"}
		}

		$this.location = $disks.LOCATION

		switch($disks.LOGICTYPE)
		{
			1 {$this.logicType = "free"}
			2 {$this.logicType = "member"}
			3 {$this.logicType = "hot_spare"}
			4 {$this.logicType = "cache"}
		}

		$this.manufacter = $disks.MANUFACTURER
		$this.model = $disks.MODEL
		$this.multipath = $disks.MULTIPATH
		$this.parentId = $disks.PARENTID
		$this.{Parent Type} = $disks.PARENTTYPE
		$this.poolId = $disks.POOLID
		$this.poolName = $disks.POOLNAME
		$this.poolTierId = $disks.POOLTIERID
		$this.progress = $disks.PROGRESS
		$this.remainLife = $disks.REMAINLIFE

		switch($disks.RUNNINGSTATUS)
		{
			0 {$this.runningStatus = "unknown"}
			1 {$this.runningStatus = "Normal"}
			14 {$this.runningStatus = "pre-copy"}
			16 {$this.runningStatus = "reconstruction"}
			27 {$this.runningStatus = "online"}
			16 {$this.runningStatus = "offline"}
		}

		$this.runtime = $disks.RUNTIME
		$this.sectors = $disks.SECTORS
		$this.sectorSize = $disks.SECTORSIZE
		$this.serialNumber = $disks.SERIALNUMBER
		$this.smartCachePoolId = $disks.SMARTCACHEPOOLID
		$this.speedRPM = $disks.SPEEDRPM
		$this.storeEngineId = $disks.STORAGEENGINEID
		$this.temperature = $disks.TEMPERATURE

		switch($disks.TYPE)
		{
			0 {$this.type = "FC"}
			1 {$this.type = "SAS"}
			2 {$this.type = "SATA"}
			3 {$this.type = "SSD"}
			4 {$this.type = "NL-SAS"}
			5 {$this.type = "SLC SSD"}
			6 {$this.type = "MLC SSD"}
			7 {$this.type = "FC SED"}
			8 {$this.type = "SAS SED"}
			9 {$this.type = "SATA SED"}
			10 {$this.type = "SSD SED"}
			11 {$this.type = "NL-SAS SED"}
			12 {$this.type = "SLC SSD SED"}
			13 {$this.type = "MLC SSD SED"}
		}

		$this.barCode = $disks.barcode
		$this.formartProgress = $disks.formatProgress
		$this.formatRemainTime = $disks.formatRemainTime
		$this.manufacterCapacity = $disks.manuCapacity
	}
}

class OceanStorHost
{
	#Define Properties
	[string]$description
	[string]$healthstatus
	[string]$id
	[string]$initiatornum
	[string]$ip
	[string]$isadd2hostgroup
	[string]$location
	[string]$model
	[string]$name
	[string]$networkname
	[string]$operationsystem
	[string]$parentid
	[string]$parentname
	[string]$parenttype
	[string]$runningstatus
	[string]$type

	OceanStorHost ([array] $hostReceived)
	{
		$this.description = $hostReceived.DESCRIPTION
		$this.healthstatus = $hostReceived.HEALTHSTATUS
		$this.id = $hostReceived.ID
		$this.initiatornum = $hostReceived.INITIATORNUM
		$this.ip = $hostReceived.IP
		$this.isadd2hostgroup = $hostReceived.ISADD2HOSTGROUP
		$this.location = $hostReceived.LOCATION
		$this.model = $hostReceived.MODEL
		$this.name = $hostReceived.NAME
		$this.networkname = $hostReceived.NETWORKNAME
		$this.operationsystem = $hostReceived.OPERATIONSYSTEM
		$this.parentid = $hostReceived.PARENTID
		$this.parentname = $hostReceived.PARENTNAME
		$this.parenttype = $hostReceived.PARENTTYPE
		$this.runningstatus = $hostReceived.RUNNINGSTATUS
		$this.type = $hostReceived.TYPE
	}

}

class OceanstorDeviceManager
{
    #Define Hostname Property
	hidden [string]$Hostname

	#Define Host Credentials Property
	hidden [System.Management.Automation.PSCredential]$Credentials

	#Define DeviceID Property
	hidden [string]$DeviceId

	#Define WebSession Property
	hidden [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession

	#Define Headers Array Property
	hidden [System.Collections.IDictionary]$Headers

	#Define iBaseToken Property
	hidden [string]$iBaseToken

    # Constructor
    OceanstorDeviceManager ([PSCustomObject] $logonSession, [System.Collections.IDictionary]$SessionHeader, [Microsoft.PowerShell.Commands.WebRequestSession]$webSession, [string] $hostname, [System.Management.Automation.PSCredential]$credentials)
    {
        $this.DeviceId = $logonsession.data.deviceid
        $this.WebSession = $WebSession
        $this.Headers = $SessionHeader
        $this.iBaseToken = $logonsession.data.iBaseToken
        $this.Credentials = $credentials
        $this.Hostname = $hostname
    }
}

#functions module
function connect-deviceManager {
	[Cmdletbinding()]
  Param(
  [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$true)]
  [String]$Hostname,
  [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=1,Mandatory=$false)]
  [boolean]$Return = $false
  )

    $credentials = Get-Credential
    $username = $credentials.GetNetworkCredential().UserName
    $password = $credentials.GetNetworkCredential().Password

    $body = @{username = $username;
            password = $password;
            scope = 0}

    $webSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession

    $logonsession=Invoke-RestMethod -Method Post -Uri "https://$($Hostname):8088/deviceManager/rest/xxxxx/sessions" -Body (ConvertTo-Json $body) -SessionVariable WebSession

    if ($logonsession.error.code -ne 0)
    {
        Write-Host $logonsession.error
        exit
    }
    $CredentialsBytes = [System.Text.Encoding]::UTF8.GetBytes(-join("{0}:{1}" -f $username,$password))
    $EncodedCredentials = [Convert]::ToBase64String($CredentialsBytes)

    $SessionHeader = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $SessionHeader.Add("Authorization", "Basic $EncodedCredentials")
    $SessionHeader.Add("iBaseToken", $logonsession.data.iBaseToken)

    $connection = [OceanstorDeviceManager]::new($logonSession,$SessionHeader,$webSession,$Hostname,$credentials)

	$connection.Hostname

    if ($return -eq $true)
    {
       return $connection
    } else {
       $global:deviceManager = $connection
    }
}

function invoke-DeviceManager{
    [Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [pscustomobject]$WebSession,
    [Parameter(Position=1,Mandatory=$true)]
        [ValidateSet('GET','POST','PUT','DELETE')]
        [string]$Method,
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=2,Mandatory=$true)]
        [String]$Resource
	)

    if ($WebSession){
        $session = $WebSession
    } else {
        $session = $deviceManager
    }

    $RestURI = "https://$($session.hostname):8088/deviceManager/rest/$($session.DeviceId)/$resource"

	$result = Invoke-RestMethod -Method $Method -uri $RestURI -Headers $session.Headers -WebSession $session.WebSession -ContentType "application/json" -Credential $session.Credentials

    if ($result.error.code -ne 0)
    {
        Write-Host $result.error
        exit
    }

	return $result
}

function get-DMSystem
{
	[Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [pscustomobject]$WebSession
	)

	if ($WebSession){
        $session = $WebSession
    } else {
        $session = $deviceManager
    }

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "system/" | Select-Object -ExpandProperty data
    $response = $response -replace "[@{}]"
    [array]$systemArray = $response.Split(";")

    $result = [OceanStorSystem]::new($systemArray)

	return $result
}

function get-DMluns
{
	[Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [pscustomobject]$WebSession
	)

	if ($WebSession){
        $session = $WebSession
    } else {
        $session = $deviceManager
    }

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "lun" | Select-Object -ExpandProperty data
    $StorageLuns = New-Object System.Collections.ArrayList

	foreach ($tlun in $response)
	{
		$lun = [OceanstorDeviceLun]::new($tlun)
		$StorageLuns += $lun
	}

	$result = $storageLuns

	return $result
}