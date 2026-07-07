function New-DMHyperMetroPair {
    <#
    .SYNOPSIS
        Creates an OceanStor SAN HyperMetro pair.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'ById')]
    [OutputType('OceanstorHyperMetroPair')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DomainId,

        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DomainName,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$LocalLunId,

        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$LocalLunName,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RemoteLunId,

        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RemoteLunName,

        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RemoteDeviceId,

        [switch]$FirstSync,

        [ValidateSet('Automatic', 'Manual')]
        [string]$RecoveryPolicy = 'Automatic',

        [ValidateSet('Low', 'Medium', 'High', 'Highest')]
        [string]$Speed = 'Medium',

        [switch]$Isolation,

        [ValidateRange(10, 30000)]
        [int]$IsolationThresholdTime,

        [hashtable]$ApiProperties
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

    $resolvedDomainId = if ($DomainName) {
        $domain = @(Get-DMHyperMetroDomain -WebSession $session -Name $DomainName | Where-Object Name -EQ $DomainName)[0]
        if ($null -eq $domain) { throw "HyperMetro domain '$DomainName' was not found." }
        $domain.Id
    }
    else {
        $DomainId
    }
    $resolvedLocalLunId = if ($LocalLunName) {
        $lun = @(Get-DMlun -WebSession $session -Name $LocalLunName | Where-Object Name -EQ $LocalLunName)[0]
        if ($null -eq $lun) { throw "Local LUN '$LocalLunName' was not found." }
        $lun.Id
    }
    else {
        $LocalLunId
    }
    $resolvedRemoteLunId = if ($RemoteLunName) {
        $remoteLun = @(Get-DMRemoteLun -WebSession $session -RemoteDeviceId $RemoteDeviceId -RemoteServiceType HyperMetroSecondaryLun -Name $RemoteLunName | Where-Object Name -EQ $RemoteLunName)[0]
        if ($null -eq $remoteLun) { throw "Remote LUN '$RemoteLunName' was not found on remote device '$RemoteDeviceId'." }
        $remoteLun.'Remote Lun Id'
    }
    else {
        $RemoteLunId
    }

    $body = @{
        DOMAINID       = $resolvedDomainId
        HCRESOURCETYPE = 1
        LOCALOBJID     = $resolvedLocalLunId
        REMOTEOBJID    = $resolvedRemoteLunId
        ISFIRSTSYNC    = [bool]$FirstSync
        RECOVERYPOLICY = ConvertTo-DMDrRecoveryPolicyCode $RecoveryPolicy
        SPEED          = ConvertTo-DMDrSpeedCode $Speed
    }
    Add-DMOptionalBodyValue -Body $body -Key 'isIsolation' -Value ([bool]$Isolation) -IsPresent $PSBoundParameters.ContainsKey('Isolation')
    Add-DMOptionalBodyValue -Body $body -Key 'isolationThresholdTime' -Value $IsolationThresholdTime -IsPresent $PSBoundParameters.ContainsKey('IsolationThresholdTime')
    if ($ApiProperties) {
        foreach ($key in $ApiProperties.Keys) {
            $body[$key] = $ApiProperties[$key]
        }
    }

    if ($PSCmdlet.ShouldProcess("$resolvedLocalLunId -> $resolvedRemoteLunId", 'Create HyperMetro pair')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'HyperMetroPair' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        if ($response.error.Code -eq 0) {
            return [OceanstorHyperMetroPair]::new($response.data, $session)
        }
        return $response.error
    }
}
