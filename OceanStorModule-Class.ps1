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
	[hashtable]$testing
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
		$this.testing = $SystemProperties

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
		$this.dedupeSavedRatio = $LunReceived.DEDUPSAVEDRATIO * $LunSectorSize / 1GB

		if ($LunReceived.ENABLECOMPRESSION -eq "FALSE")
		{
			$this.compressionEnabled = $false
		} elseif ($LunReceived.ENABLECOMPRESSION -eq "TRUE")
		{
			$this.compressionEnabled = $true
		}

		$this.compressionSavedCapacity = $LunReceived.COMPRESSIONSAVEDCAPACITY * $LunSectorSize / 1GB
		$this.compressionSavedRatio = $LunReceived.COMPRESSIONSAVEDRATIO * $LunSectorSize / 1GB

	}
}

class OceanstorDeviceManager
{
	#Define Hostname Property
	[string]$Hostname

	#Define Host Credentials Property
	hidden [System.Management.Automation.PSCredential]$Credentials

	#Define DeviceID Property
	[string]$DeviceId

	#Define WebSession Property
	hidden [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession

	#Define Headers Array Property
	hidden [System.Collections.IDictionary]$Headers

	#Define iBaseToken Property
	hidden [string]$iBaseToken

	#Define Error
	[String]$error

	#define System Array
	[OceanStorSystem]$System

	#Define Alarm Count
	[string]$Alarms

	#Define vStore Count
	[string]$vStores

	#define Luns
	[array]$Luns

	#Define SessionToken Method TODO

	#Define SessionError Method TODO

    # Constructor
    OceanstorDeviceManager ([String] $Hostname, [String]$username, [String]$password)
    {
		$this.Credentials=New-Object System.Management.Automation.PsCredential($username,$(ConvertTo-SecureString -String $password -AsPlainText -force))

		$body = @{username = $username;
        		password = $password;
        		scope = 0}

		$thisSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
		$logonsession=Invoke-RestMethod -Method Post -Uri "https://$($Hostname):8088/deviceManager/rest/xxxxx/sessions" -Body (ConvertTo-Json $body) -SessionVariable thisSession

    	$CredentialsBytes = [System.Text.Encoding]::UTF8.GetBytes(-join("{0}:{1}" -f $username,$password))
    	$EncodedCredentials = [Convert]::ToBase64String($CredentialsBytes)

    	$SessionHeader = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    	$SessionHeader.Add("Authorization", "Basic $EncodedCredentials")
    	$SessionHeader.Add("iBaseToken", $logonsession.data.iBaseToken)

		$this.Hostname = $Hostname
     	$this.DeviceId = $logonsession.data.deviceid
        $this.WebSession = $thisSession
        $this.Headers = $SessionHeader
        $this.iBaseToken = $logonsession.data.iBaseToken
        $this.error = $logonsession.error
		$this.getSystem()
		$this.RefreshAlarmsCount()
		$this.RefreshVstoresCount()
		$this.RefreshLuns()
    }

	[pscustomobject] invokeRestSimple([string]$Method,[string]$resource)
	{
		$RestURI = "https://$($this.Hostname):8088/deviceManager/rest/$($this.DeviceId)/$resource"

		$result = Invoke-RestMethod -Method $Method -uri $RestURI -Headers $this.Headers -WebSession $this.WebSession -ContentType "application/json" -Credential $this.Credentials 

		return $result
    }

	hidden [void] getSystem()
	{
		$response = $($this.invokeRestSimple("GET","system/")) | Select-Object -ExpandProperty data
		$response = $response -replace "[@{}]"
		[array]$systemArray = $response.Split(";")

		$this.system = [OceanStorSystem]::new($systemArray)

	}

	[Void] RefreshAlarmsCount()
	{
		$response = $($this.invokeRestSimple("GET","alarm/currentalarm")) | Select-Object -ExcludeProperty error

		$this.Alarms = $response.data.count
	}

	[Void] RefreshVstoresCount()
	{
		$response = $this.invokeRestSimple("GET","vstore/count/")

		$this.vStores = $response.data.count
	}

	[array]$testing

	[string] RefreshLuns()
	{
		$response = $this.invokeRestSimple("GET","lun") | Select-Object -ExpandProperty data
		$this.testing = $response
 		$StorageLuns = New-Object System.Collections.ArrayList
		foreach ($tlun in $response)
 		{
			$lun = [OceanstorDeviceLun]::new($tlun)
			$StorageLuns += $lun
		}

		$this.Luns = $storageLuns
		Return $true
	}
}




















