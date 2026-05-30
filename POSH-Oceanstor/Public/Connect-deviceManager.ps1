function Connect-deviceManager {
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
		is an optional compatibility switch. When supplied, the function prompts for credentials securely.
		If neither Credential nor LoginUser/LoginPwd is supplied, a secure credential prompt is also used by default.
	.PARAMETER Credential
		is an optional PSCredential for unattended connections without storing a plain text password in a script.
	.PARAMETER LoginUser
		is a mandatory string when LoginPwd is provided. Is the login username to be used in the connection.
	.PARAMETER LoginPWD
		is a mandatory SecureString when LoginUser is provided.
	.INPUTS

	.OUTPUTS
		Creates a object connection to a Huawei Storage Device

	.EXAMPLE
		Example syntax for running that sets $deviceManager global Variable Session
		PS C:\> Connect-deviceManager -Hostname storage.domain.tld

		Example syntax for runnign that returns a session object connection
		PS C:\> $storage = Connect-deviceManager -Hostname storage.domain.tld -Return $true -Credential $credential

	.NOTES
		Filename: Connect-deviceManager.ps1
		Author: Joao Carmona
		Modified date: 2022-05-22
		Version 0.2

	.LINK
	#>
    [Cmdletbinding(DefaultParameterSetName = 'Prompt')]
    param(
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $true)]
        [String]$Hostname,
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 1, Mandatory = $false)]
        [boolean]$Return = $false,
        [Parameter(ParameterSetName = 'Prompt')]
        [switch]$Secure = $false,
        [Parameter(Mandatory = $true, ParameterSetName = 'Credential')]
        [pscredential]$Credential,
        [Parameter(Mandatory = $true, ParameterSetName = 'SecurePassword')]
        [String]$LoginUser,
        [Parameter(Mandatory = $true, ParameterSetName = 'SecurePassword')]
        [securestring]$LoginPwd
    )

    switch ($PSCmdlet.ParameterSetName) {
        'Credential' {
            $credentials = $Credential
        }
        'SecurePassword' {
            $credentials = [pscredential]::new($LoginUser, $LoginPwd)
        }
        default {
            $credentials = Get-Credential
        }
    }

    $username = $credentials.GetNetworkCredential().UserName
    $password = $credentials.GetNetworkCredential().Password

    $body = @{username = $username;
        password       = $password;
        scope          = 0
    }

    $webSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession

    $logonsession = Invoke-RestMethod -Method Post -Uri "https://$($Hostname):8088/deviceManager/rest/xxxxx/sessions" -Body (ConvertTo-Json $body) -SkipCertificateCheck -SessionVariable WebSession

    if ($logonsession.error.code -ne 0) {
        #Write-Host $logonsession.error
        $SessionError = $logonsession.error
        Write-DMError -SessionError $SessionError
        exit
    }

    $CredentialsBytes = [System.Text.Encoding]::UTF8.GetBytes( -join ("{0}:{1}" -f $username, $password))
    $EncodedCredentials = [Convert]::ToBase64String($CredentialsBytes)

    $SessionHeader = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $SessionHeader.Add("Authorization", "Basic $EncodedCredentials")
    $SessionHeader.Add("iBaseToken", $logonsession.data.iBaseToken)

    $connection = [OceanstorSession]::new($logonSession, $SessionHeader, $webSession, $Hostname)

    if ($return -eq $true) {
        return $connection
    }
    else {
        $global:deviceManager = $connection
    }
}
#Export-ModuleMember -Variable 'logonsession'
