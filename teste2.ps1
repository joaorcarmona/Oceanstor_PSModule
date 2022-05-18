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

function connect-deviceManager {
	[Cmdletbinding()]
        Param(
            [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$true)]
                [Alias('IP','FQDN')]
                [String]$Hostname,
            [Parameter(ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$false,Position=1,Mandatory=$false)]
                [boolean]$Return
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

    if ($return = $true)
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

    $RestURI = "https://$($session.Hostname):8088/deviceManager/rest/$($session.DeviceId)/$resource"

	$result = Invoke-RestMethod -Method $Method -uri $RestURI -Headers $session.Headers -WebSession $session.WebSession -ContentType "application/json" -Credential $session.Credentials

    if ($result.error.code -ne 0)
    {
        Write-Host $result.error
        exit
    }

	return $result
}

function get-DMSystem()
{
    $response = $($this.invokeRestSimple("GET","system/")) | Select-Object -ExpandProperty data
    $response = $response -replace "[@{}]"
    [array]$systemArray = $response.Split(";")

    $this.system = [OceanStorSystem]::new($systemArray)

}
