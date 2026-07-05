function Save-DMDeviceManagerFile {
    <#
    .SYNOPSIS
        Downloads a binary file from the OceanStor REST API to disk.

    .DESCRIPTION
        Invoke-DeviceManager always parses the response body as JSON via Invoke-RestMethod, which
        corrupts binary payloads such as the report-task export zip. This helper mirrors
        Invoke-DeviceManager's session/header/TLS wiring but calls Invoke-WebRequest -OutFile
        instead, so response bytes are written to disk untouched.

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .PARAMETER Resource
        The API resource path (relative), e.g. 'pms/report_task/file?log_id=1'.

    .PARAMETER OutFile
        Destination file path.

    .PARAMETER TimeoutSec
        Optional request timeout in seconds.

    .PARAMETER ApiV2
        Route through /api/v2/ instead of the default /deviceManager/rest/{deviceId}/ base.

    .INPUTS
        None

    .OUTPUTS
        System.IO.FileInfo

    .EXAMPLE
        PS> Save-DMDeviceManagerFile -Resource 'pms/report_task/file?log_id=1' -ApiV2 -OutFile 'C:\temp\report.zip'

    .NOTES
        Filename: Save-DMDeviceManagerFile.ps1
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true)]
        [string]$Resource,

        [Parameter(Mandatory = $true)]
        [string]$OutFile,

        [int]$TimeoutSec,

        [switch]$ApiV2
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    if ($null -eq $session) {
        throw 'Save-DMDeviceManagerFile: no session available. Connect first, or pass -WebSession.'
    }

    $restUri = if ($ApiV2) {
        "https://$($session.hostname):8088/api/v2/$Resource"
    }
    else {
        "https://$($session.hostname):8088/deviceManager/rest/$($session.DeviceId)/$Resource"
    }

    $invokeParams = @{
        Method     = 'GET'
        Uri        = $restUri
        Headers    = $session.Headers
        WebSession = $session.WebSession
        OutFile    = $OutFile
    }
    if ($PSBoundParameters.ContainsKey('TimeoutSec')) {
        $invokeParams.TimeoutSec = $TimeoutSec
    }
    if ($session.SkipCertificateCheck) {
        $invokeParams.SkipCertificateCheck = $true
    }

    Invoke-WebRequest @invokeParams | Out-Null

    return Get-Item -LiteralPath $OutFile
}
