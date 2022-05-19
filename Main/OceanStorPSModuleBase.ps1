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