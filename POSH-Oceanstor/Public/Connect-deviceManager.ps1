function Connect-deviceManager {
    <#
	.SYNOPSIS
		Connects to a Huawei OceanStor array by REST.

	.DESCRIPTION
		Starts a REST session to a Huawei OceanStor DeviceManager endpoint. When replacing the
		global $deviceManager session (PassThru not specified), any existing global session is
		closed first on a best-effort basis to avoid leaking a connection slot on the array.

	.PARAMETER Hostname
		Mandatory hostname or IP address of the Huawei OceanStor array.
	.PARAMETER PassThru
		When supplied, the connection object is returned instead of being assigned to the global $deviceManager variable.
		The legacy -Return switch is accepted as an alias for backward compatibility.
		Note: callers using -Return $true must change to -Return (without $true) since this is now a switch.
	.PARAMETER Secure
		is an optional compatibility switch. When supplied, the function prompts for credentials securely.
		If neither Credential nor LoginUser/LoginPwd is supplied, a secure credential prompt is also used by default.
	.PARAMETER Credential
		is an optional PSCredential for unattended connections without storing a plain text password in a script.
	.PARAMETER LoginUser
		is a mandatory string when LoginPwd is provided. Is the login username to be used in the connection.
	.PARAMETER LoginPWD
		is a mandatory SecureString when LoginUser is provided.
	.PARAMETER SkipCertificateCheck
		When supplied, disables TLS certificate validation for the login request and all requests made with the returned session.
		This should only be used for lab/test arrays or environments with self-signed certificates.
	.INPUTS
		System.String
		System.Management.Automation.PSCredential

		You can pipe a hostname to Hostname. Credentials can be supplied with Credential or with LoginUser and LoginPwd.

	.OUTPUTS
		OceanstorSession

		Returns an OceanStor session object when Return is true. Otherwise, assigns the session to the global deviceManager variable.

	.EXAMPLE
		Example syntax for running that sets the $deviceManager global WebSession object.
		PS C:\> Connect-deviceManager -Hostname storage.domain.tld

		Example syntax for returning a WebSession connection object.
		PS C:\> $storage = Connect-deviceManager -Hostname storage.domain.tld -PassThru -Credential $credential

	.NOTES
		Filename: Connect-deviceManager.ps1

	.LINK
	#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [Cmdletbinding(DefaultParameterSetName = 'Prompt')]
    param(
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $true)]
        [String]$Hostname,
        [Alias('Return')]
        [switch]$PassThru,
        [Parameter(ParameterSetName = 'Prompt')]
        [switch]$Secure = $false,
        [Parameter(Mandatory = $true, ParameterSetName = 'Credential')]
        [pscredential]$Credential,
        [Parameter(Mandatory = $true, ParameterSetName = 'SecurePassword')]
        [String]$LoginUser,
        [Parameter(Mandatory = $true, ParameterSetName = 'SecurePassword')]
        [securestring]$LoginPwd,
        [switch]$SkipCertificateCheck
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

    # Keep certificate validation enabled unless the caller explicitly opts out.
    $invokeParams = @{
        Method          = 'Post'
        Uri             = "https://$($Hostname):8088/deviceManager/rest/xxxxx/sessions"
        Body            = ConvertTo-Json $body
        SessionVariable = 'WebSession'
    }
    if ($SkipCertificateCheck) {
        $invokeParams.SkipCertificateCheck = $true
    }

    $logonsession = Invoke-RestMethod @invokeParams

    if ($logonsession.error.code -ne 0) {
        $SessionError = $logonsession.error
        Write-DMError -SessionError $SessionError
        # throw instead of exit to avoid terminating the caller's session
        throw "Login failed for host '$Hostname': $($SessionError.description)"
    }

    # Wipe plaintext credentials from memory now that the login body has been sent.
    # The Basic Auth header is not carried into the session — iBaseToken alone
    # authenticates all subsequent calls, so the credential strings are not needed again.
    $username = $null
    $password = $null
    $body     = $null

    $SessionHeader = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $SessionHeader.Add("iBaseToken", $logonsession.data.iBaseToken)

    $connection = [OceanstorSession]::new($logonSession, $SessionHeader, $webSession, $Hostname)
    $connection.SkipCertificateCheck = [bool]$SkipCertificateCheck
    $connection.Version = (Get-DMSystem -WebSession $connection).version

    if ($PassThru) {
        return $connection
    }
    else {
        if ($global:deviceManager) {
            try {
                Disconnect-deviceManager -WebSession $global:deviceManager
            }
            catch {
                Write-Warning "Failed to close the previous OceanStor session on '$($global:deviceManager.Hostname)': $($_.Exception.Message)"
            }
        }
        $global:deviceManager = $connection
    }
}
#Export-ModuleMember -Variable 'logonsession'
