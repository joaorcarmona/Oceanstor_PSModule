function Set-DMSyslogNotification {
    <#
    .SYNOPSIS
        Modifies global OceanStor Syslog notification settings.

    .PARAMETER Property
        Optional raw REST body fields (e.g. syslogFormat) not covered by a named parameter below.

    .PARAMETER Severity
        Optional minimum alarm severity that triggers syslog notification. Valid values: 2 (Info),
        3 (Warning), 5 (Major), 6 (Critical). Maps to CMO_ALARM_SYSLOG_SEVERITY.

    .PARAMETER Port
        Optional syslog receiver port, 1-65535. Maps to SYSLOG_SERVER_PORT.

    .PARAMETER Protocol
        Optional syslog transport protocol: UDP, TCP, or TCP+SSL. Maps to
        SYSLOG_SERVER_CHANNEL_PROTOCOL. There is no "facility" field in the OceanStor Dorado 6.1.6
        REST syslog resource, so no -Facility parameter is offered.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory = $false)][hashtable]$Property = @{},
        [Parameter(Mandatory = $false)]
        [ValidateSet(2, 3, 5, 6)]
        [int]$Severity,
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 65535)]
        [int]$Port,
        [Parameter(Mandatory = $false)]
        [ValidateSet('UDP', 'TCP', 'TCP+SSL')]
        [string]$Protocol
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

    $namedParameters = @{}
    if ($PSBoundParameters.ContainsKey('Severity')) { $namedParameters.Severity = $Severity }
    if ($PSBoundParameters.ContainsKey('Port')) { $namedParameters.Port = $Port }
    if ($PSBoundParameters.ContainsKey('Protocol')) { $namedParameters.Protocol = $Protocol }

    $namedBody = ConvertTo-DMRequestBody -BoundParameters $namedParameters -Map @{
        Severity = 'CMO_ALARM_SYSLOG_SEVERITY'
        Port     = 'SYSLOG_SERVER_PORT'
        Protocol = 'SYSLOG_SERVER_CHANNEL_PROTOCOL'
    }

    if ($namedBody.ContainsKey('SYSLOG_SERVER_CHANNEL_PROTOCOL')) {
        $namedBody.SYSLOG_SERVER_CHANNEL_PROTOCOL = @{ 'UDP' = 1; 'TCP' = 2; 'TCP+SSL' = 3 }[$Protocol]
    }

    $body = @{} + $Property
    foreach ($key in $namedBody.Keys) {
        $body[$key] = $namedBody[$key]
    }

    if ($PSCmdlet.ShouldProcess('Syslog notification settings', 'Modify')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'syslog' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
