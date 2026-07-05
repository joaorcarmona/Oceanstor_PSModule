function Set-DMHyperMetroDomain {
    <#
    .SYNOPSIS
        Modifies an OceanStor SAN HyperMetro domain.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_.-]{0,30}$')]
        [string]$NewName,

        [ValidateLength(0, 127)]
        [string]$Description,

        [hashtable]$ApiProperties
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $domainId = Resolve-DMHyperMetroDomainId -WebSession $session -Id $Id -Name $Name
    $body = @{ ID = $domainId }
    Add-DMOptionalBodyValue -Body $body -Key 'NAME' -Value $NewName -IsPresent $PSBoundParameters.ContainsKey('NewName')
    Add-DMOptionalBodyValue -Body $body -Key 'DESCRIPTION' -Value $Description -IsPresent $PSBoundParameters.ContainsKey('Description')
    if ($ApiProperties) {
        foreach ($key in $ApiProperties.Keys) {
            $body[$key] = $ApiProperties[$key]
        }
    }
    if ($body.Count -le 1) { throw 'Specify at least one HyperMetro domain property to modify.' }

    if ($PSCmdlet.ShouldProcess($domainId, 'Modify SAN HyperMetro domain')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource "HyperMetroDomain/$domainId" -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
