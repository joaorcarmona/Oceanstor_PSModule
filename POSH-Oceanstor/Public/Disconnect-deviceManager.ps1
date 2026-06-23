function Disconnect-deviceManager {
    <#
    .SYNOPSIS
        Closes an OceanStor REST session.

    .DESCRIPTION
        Issues a DELETE against the DeviceManager sessions endpoint to release the
        server-side session. OceanStor caps concurrent sessions, so callers should
        always disconnect when finished to avoid exhausting the session pool.

        When no WebSession parameter is supplied the function falls back to the
        global $deviceManager variable and clears it after a successful logout.

    .PARAMETER WebSession
        Optional OceanStor session object. If not supplied, the global $deviceManager
        variable is used.

    .INPUTS
        System.Management.Automation.PSCustomObject

        You can pipe an OceanStor session object to WebSession.

    .OUTPUTS
        None

    .EXAMPLE
        Disconnect the default global session:
        PS C:\> Disconnect-deviceManager

    .EXAMPLE
        Disconnect a specific session returned by Connect-deviceManager -PassThru:
        PS C:\> Disconnect-deviceManager -WebSession $storage

    .EXAMPLE
        Safe automation pattern using try/finally:
        PS C:\> $session = Connect-deviceManager -Hostname storage.domain.tld -PassThru -Credential $cred
        PS C:\> try {
        PS C:\>     Get-DMSystem -WebSession $session
        PS C:\> } finally {
        PS C:\>     Disconnect-deviceManager -WebSession $session
        PS C:\> }

    .NOTES
        Filename: Disconnect-deviceManager.ps1

    .LINK
    #>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession
    )

    $usingGlobal = $false

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $deviceManager
        $usingGlobal = $true
    }

    if (-not $session) {
        throw "No active OceanStor session. Supply -WebSession or connect first with Connect-deviceManager."
    }

    $response = Invoke-DeviceManager -WebSession $session -Method "DELETE" -Resource "sessions"

    if ($response.error.code -ne 0) {
        $SessionError = $response.error
        Write-DMError -SessionError $SessionError
        throw "Logout failed for host '$($session.Hostname)': $($SessionError.description)"
    }

    if ($usingGlobal) {
        $global:deviceManager = $null
    }
}
