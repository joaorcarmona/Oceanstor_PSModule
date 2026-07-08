function Set-DMHyperMetroPairPreferredPolicy {
    <#
    .SYNOPSIS
        Modifies the preferred-site arbitration policy of an OceanStor HyperMetro pair.

    .DESCRIPTION
        Dedicated wrapper for the documented HyperMetroPair/MODIFY_PREFERRED_POLICY
        endpoint (OceanStor Dorado 6.1.6 REST Interface Reference, 4.9.7.3.3 "Interface
        for Modifying the Preferred Site Policy for Arbitration of a HyperMetro Pair").
        The arbitration policy governs which site wins on a link failure, so this is a
        High-impact DR mutator with SupportsShouldProcess.

        Prefer this wrapper over passing preferredSitePolicyForArbitration through
        Set-DMHyperMetroPair -ApiProperties: MODIFY_PREFERRED_POLICY is a distinct
        endpoint from the in-place HyperMetroPair/{id} modify.

    .PARAMETER PreferredSitePolicy
        Preferred site policy for arbitration:
        UserDefined  (1) - the preferred site is set explicitly by the operator.
        ServiceBased (2) - the preferred site is determined based on service I/Os.
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

        [Parameter(Mandatory = $true)]
        [ValidateSet('UserDefined', 'ServiceBased')]
        [string]$PreferredSitePolicy
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $pairId = Resolve-DMHyperMetroPairId -WebSession $session -Id $Id -Name $Name

    $policyCode = if ($PreferredSitePolicy -eq 'ServiceBased') { 2 } else { 1 }
    $body = @{
        ID                              = $pairId
        preferredSitePolicyForArbitration = $policyCode
    }

    if ($PSCmdlet.ShouldProcess($pairId, "Set HyperMetro pair preferred arbitration policy to $PreferredSitePolicy")) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'HyperMetroPair/MODIFY_PREFERRED_POLICY' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
