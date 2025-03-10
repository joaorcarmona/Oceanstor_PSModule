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
	.PARAMETER Secure
		is optional switch, to connect using secure credentials. If set, the function will request credentials in a more secure way
	.PARAMETER Unsecure
		is optional switch, to connect using unsecure credentials. If set, the LoginUser and LoginPWD are mandatory. Both will be pass in plain text
	.PARAMETER LoginUser
		is a mandatory string if unsecure switch is set. Is the login username to be used in the connection
	.PARAMETER LoginPWD
		is a mandatory string if unsecure switch is set. Is the login password to be used in the connection (clear text)
	.INPUTS

	.OUTPUTS
		Creates a object connection to a Huawei Storage Device

	.EXAMPLE
		Example syntax for running that sets $deviceManager global Variable Session 
		PS C:\> connect-deviceManager -$hostname storage.domain.tld -Secure

		Example syntax for runnign that returns a session object connection
		PS C:\> $storage = connect-deviceManager -$hostname storage.domain.tld -return $true -Secure

	.NOTES
		Filename: connect-deviceManager.ps1
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
			[boolean]$Return = $false,
		[Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=2,Mandatory=$true,ParameterSetName="secure")]
			[switch]$Secure = $false,
		[Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=3,Mandatory=$false,ParameterSetName="unsecure")]
			[String]$LoginUser,
		[Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=4,Mandatory=$true,ParameterSetName="unsecure")]
			[String]$LoginPwd,
		[Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=5,Mandatory=$true,ParameterSetName="unsecure")]
			[switch]$Unsecure = $false
	)

	if ($Secure -eq $true)
	{
		[pscredential]$credentials = Get-Credential
	} else {
		[securestring]$SecPassword = ConvertTo-SecureString -String	$LoginPwd -AsPlainText -Force
		[pscredential]$credentials = New-Object System.Management.Automation.PSCredential ($LoginUser, $SecPassword)
	}

	$username = $credentials.GetNetworkCredential().UserName
	$password = $credentials.GetNetworkCredential().Password

    $body = @{username = $username;
            password = $password;
            scope = 0}

    $webSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession

    $logonsession=Invoke-RestMethod -Method Post -Uri "https://$($Hostname):8088/deviceManager/rest/xxxxx/sessions" -Body (ConvertTo-Json $body) -SkipCertificateCheck -SessionVariable WebSession

    if ($logonsession.error.code -ne 0)
    {
        #Write-Host $logonsession.error
		$SessionError = $logonsession.error
		write-DMError -SessionError $SessionError
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
Export-ModuleMember -Variable 'logonsession'