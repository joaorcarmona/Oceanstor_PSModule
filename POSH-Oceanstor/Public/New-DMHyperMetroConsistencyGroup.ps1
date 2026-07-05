function New-DMHyperMetroConsistencyGroup {
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'ByDomainId')]
    [OutputType([OceanstorHyperMetroConsistencyGroup])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_.-]{0,30}$')]
        [string]$Name,

        [Parameter(ParameterSetName = 'ByDomainId', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DomainId,

        [Parameter(ParameterSetName = 'ByDomainName', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DomainName,

        [ValidateLength(0, 127)]
        [string]$Description,

        [ValidateSet('Automatic', 'Manual')]
        [string]$RecoveryPolicy = 'Automatic',

        [ValidateSet('Low', 'Medium', 'High', 'Highest')]
        [string]$Speed = 'Medium',

        [bool]$Isolation,
        [ValidateRange(10, 30000)][int]$IsolationThresholdTime,
        [string]$LocalProtectionGroupId,
        [string]$RemoteProtectionGroupId,
        [string]$RemoteVStoreId,
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

    $body = @{
        NAME           = $Name
        DOMAINID       = $resolvedDomainId
        RECOVERYPOLICY = ConvertTo-DMDrRecoveryPolicyCode $RecoveryPolicy
        SPEED          = ConvertTo-DMDrSpeedCode $Speed
    }
    Add-DMOptionalBodyValue -Body $body -Key 'DESCRIPTION' -Value $Description -IsPresent $PSBoundParameters.ContainsKey('Description')
    Add-DMOptionalBodyValue -Body $body -Key 'ISISOLATION' -Value $Isolation -IsPresent $PSBoundParameters.ContainsKey('Isolation')
    Add-DMOptionalBodyValue -Body $body -Key 'ISISOLATIONTHRESHOLDTIME' -Value $IsolationThresholdTime -IsPresent $PSBoundParameters.ContainsKey('IsolationThresholdTime')
    Add-DMOptionalBodyValue -Body $body -Key 'localPgId' -Value $LocalProtectionGroupId -IsPresent $PSBoundParameters.ContainsKey('LocalProtectionGroupId')
    Add-DMOptionalBodyValue -Body $body -Key 'remotePgId' -Value $RemoteProtectionGroupId -IsPresent $PSBoundParameters.ContainsKey('RemoteProtectionGroupId')
    Add-DMOptionalBodyValue -Body $body -Key 'RMTVSTOREID' -Value $RemoteVStoreId -IsPresent $PSBoundParameters.ContainsKey('RemoteVStoreId')
    if ($ApiProperties) {
        foreach ($key in $ApiProperties.Keys) {
            $body[$key] = $ApiProperties[$key]
        }
    }

    if ($PSCmdlet.ShouldProcess($Name, 'Create HyperMetro consistency group')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'HyperMetro_ConsistentGroup' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        if ($response.error.Code -eq 0) {
            return [OceanstorHyperMetroConsistencyGroup]::new($response.data, $session)
        }
        return $response.error
    }
}
