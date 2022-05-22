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
			[boolean]$Return = $false
	)

    $credentials = Get-Credential #TODO create optional parameter for unsecure username/password to be passed as parameter
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