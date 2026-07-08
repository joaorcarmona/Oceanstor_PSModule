function Set-DMVStorePair {
    <#
    .SYNOPSIS
        Changes the IP working mode of an OceanStor HyperMetro vStore pair.

    .DESCRIPTION
        Dedicated wrapper for the documented VSTORE_PAIR/change_ip_work_mode endpoint
        (OceanStor Dorado 6.1.6 REST Interface Reference, 4.12 vStore pair "Modify").
        Changing the IP working mode alters how host access is served across the two
        sites of a HyperMetro vStore pair, so this is a High-impact mutator with
        SupportsShouldProcess.

    .PARAMETER IpWorkMode
        IP working mode of the HyperMetro vStore pair:
        LoadBalancing (1) - load-balancing working mode.
        Preferred     (2) - preferred working mode.

    .PARAMETER LocalPrefer
        IP working mode of the local site. Mandatory when IpWorkMode is Preferred:
        NonPreferred (1) or Preferred (2).

    .PARAMETER SingleSiteChange
        Change the IP working mode of one site only (isLocalChange = true). When
        omitted the change is applied to both sites (the documented default).
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter(Mandatory = $true)]
        [ValidateSet('LoadBalancing', 'Preferred')]
        [string]$IpWorkMode,

        [ValidateSet('NonPreferred', 'Preferred')]
        [string]$LocalPrefer,

        [switch]$SingleSiteChange
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

    if ($IpWorkMode -eq 'Preferred' -and -not $LocalPrefer) {
        throw 'LocalPrefer is required when IpWorkMode is Preferred.'
    }

    $body = @{
        ID         = $Id
        ipWorkMode = if ($IpWorkMode -eq 'Preferred') { 2 } else { 1 }
    }
    if ($LocalPrefer) {
        $body.isLocalPrefer = if ($LocalPrefer -eq 'Preferred') { 2 } else { 1 }
    }
    if ($SingleSiteChange) {
        $body.isLocalChange = $true
    }

    if ($PSCmdlet.ShouldProcess($Id, "Change vStore pair IP working mode to $IpWorkMode")) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'VSTORE_PAIR/change_ip_work_mode' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
