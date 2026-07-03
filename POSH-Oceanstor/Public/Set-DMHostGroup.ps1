function Set-DMHostGroup {
    <#
    .SYNOPSIS
        Modifies an OceanStor host group.
    .DESCRIPTION
        Modifies a host group by name. NewName and Description are first-class properties; ApiProperties
        passes additional Huawei host-group API fields through unchanged.

        Accepts multiple host groups from the pipeline by property name. Each host group is modified
        independently: a failure (e.g. an invalid/ambiguous name, a name collision, or a REST error)
        is reported as a non-terminating error and does not stop the rest from being processed.
        NewName is not meaningful for a batch of more than one host group.

    .PARAMETER WebSession
        Optional session returned by Connect-deviceManager. The module's cached $script:CurrentOceanstorSession session is used by default.

    .PARAMETER HostGroupName
        Existing host group name to modify.

    .PARAMETER NewName
        New name for the host group.

    .PARAMETER Description
        New description. An empty string clears the description.

    .PARAMETER ApiProperties
        Additional Huawei API modification fields to send verbatim.

    .PARAMETER VstoreId
        Optional vStore ID used to scope the operation.

    .INPUTS
        System.Management.Automation.PSCustomObject

        You can pipe an OceanStor session object to WebSession.

    .OUTPUTS
        System.Management.Automation.PSCustomObject

        Returns the OceanStor API error object indicating success or failure of the modification.

    .EXAMPLE
        PS> Set-DMHostGroup -HostGroupName 'cluster' -NewName 'cluster-prod' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName = $true, Position = 1)]
        [Alias('Name')][ValidateNotNullOrEmpty()][string]$HostGroupName,
        [ValidateLength(1, 255)][ValidatePattern('^[A-Za-z0-9_.-]+$')][string]$NewName,
        [AllowEmptyString()][ValidateLength(0, 255)][string]$Description,
        [System.Collections.IDictionary]$ApiProperties,
        [string]$VstoreId
    )

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
            $update = New-DMNamedObjectUpdate -Objects @(Get-DMhostGroup -WebSession $session -VstoreId $VstoreId) `
                -CurrentName $HostGroupName -EntityName 'host group' -ResourceBase 'hostgroup' -NewName $NewName `
                -NewNameSpecified:$($PSBoundParameters.ContainsKey('NewName')) -Description $Description `
                -DescriptionSpecified:$($PSBoundParameters.ContainsKey('Description')) -ApiProperties $ApiProperties -VstoreId $VstoreId

            if ($PSCmdlet.ShouldProcess($HostGroupName, $update.Action)) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource $update.Resource -BodyData $update.Body
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
