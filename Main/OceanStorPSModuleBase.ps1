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

#Check depencies
if (!(Get-Module -ListAvailable -Name ImportExcel )) {
	Write-Host "ImportExcel Module is not available or is not installed!`r`n"
	Write-Host "`r`n"
	Write-Host "`r`n"
	Write-Host "To install the ImportExcel Module, run the following command from the powershell command line (Powershell v5, is required):`r`n"
	Write-Host "`r`n"
	Write-Host "Install-Module -Name ImportExcel"
	Write-Host "`r`n"
	Write-Host "`r`n"
	write-Host "For more information, consult the ImportExcel page: https://github.com/dfinke/ImportExcel"
	exit
}

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

function connect-deviceManager {
	<#
	.SYNOPSIS
		Connects to a Huawei Storage by rest.

	.DESCRIPTION
		Function to start a connection to a Huawei Storage Device

	.PARAMETER Hostname
		is mandatory [string] parameter, that can be a hostname or an IP Address of the Huawei Oceanstor Device
	.PARAMETER Return
		is optional [bollean] parameter, for the function to return the the connection object or create a Global Variable $deviceManager.
		by default is false.
		If true, the connection object will be returned. If false $deviceManager Global Variable will be set. by default

	.INPUTS

	.OUTPUTS
		Creates a object connection to a Huawei Storage Device

	.EXAMPLE
		Example syntax for running that sets $deviceManager global Variable Session
		PS C:\> connect-deviceManager -$hostname storage.domain.tld

		Example syntax for runnign that returns a session object connection
		PS C:\> $storage = connect-deviceManager -$hostname storage.domain.tld -return $true

	.NOTES
		Filename: OceanstorPSModulePSBase.ps1
		Author: Joao Carmona
		Modified date: 2022-05-22
		Version 0.2

	.LINK
	#>
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

    $connection = [OceanstorSession]::new($logonSession,$SessionHeader,$webSession,$Hostname,$credentials)

    if ($return -eq $true)
    {
       return $connection
    } else {
       $global:deviceManager = $connection
    }
}

function invoke-DeviceManager{
	<#
	.SYNOPSIS
		Invokes a the Huawei Oceanstor Rest API

	.DESCRIPTION
		Function to to invoke the Huawei Oceanstor REST API, by method "GET","PUT","POST","DELETE" for any of the resources.

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used
	.PARAMETER method
		Mandatory parameter to define the REST call method to be used. Acceptable Values "GET","PUT","POST","DELETE"
	.PARAMETER resource
		Mandatory parameter to define the resource to be invoke. Any resource defines by Huawei Oceanstor REST API is acceptable

	.INPUTS

	.OUTPUTS
		returns the results of Huawei Oceanstor REST API call

	.EXAMPLE

		PS C:\> invoke-DeviceManager -webSession $session -method "GET" -resource "lun"

		OR

		PS C:\> $hosts = invoke-DeviceManager -method "GET" -resource "host"

	.NOTES
		Filename: OceanstorPSModulePSBase.ps1
		Author: Joao Carmona
		Modified date: 2022-05-22
		Version 0.2

	.LINK
	#>
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

function get-DMSystem{
	<#
	.SYNOPSIS
		To Get Huawei Oceanstor DeviceManager basic properties

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage DeviceManager basic proterties

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor DeviceManager basic properties

	.EXAMPLE

		PS C:\> get-DMSystem -webSession $session

		OR

		PS C:\> $StorageDM = get-DMSystem

	.NOTES
		Filename: OceanstorPSModulePSBase.ps1
		Author: Joao Carmona
		Modified date: 2022-05-22
		Version 0.2

	.LINK
	#>
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