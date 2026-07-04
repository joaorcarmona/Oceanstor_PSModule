<#
.SYNOPSIS
    Removes a direct OceanStor LUN-to-host mapping.

.DESCRIPTION
    Deletes a direct host-to-LUN mapping via the OceanStor mapping interface. The LUN and the host
    can each be identified by Name or by Id; Name and Id are mutually exclusive for the same
    object, enforced by PowerShell parameter sets (supplying both -LunName and -LunId, or both
    -HostName and -HostId, is a parameter-binding error). Both Name parameters are validated at
    parameter-binding time with tab completion; both Id parameters are validated too, but have no
    tab completion.
    Unlike Remove-DMHostGroupFromMappingView/Remove-DMLunGroupFromMappingView/
    Remove-DMPortGroupFromMappingView, this does not target an existing named mapping view -- the
    OceanStor REST API's legacy mappingview/REMOVE_ASSOCIATE endpoint only accepts host group, LUN
    group, or port group associations, not individual hosts or LUNs. The recommended mapping
    interface used here deletes the underlying mapping from the host/LUN pair alone, so there is
    no -MappingViewName parameter.
    The cmdlet supports -WhatIf and -Confirm.

    Accepts multiple LUNs from the pipeline by property name (Name only; Id is not pipeline-bound).
    Each is resolved and unmapped from the same host independently: a REST error is reported as a
    non-terminating error and does not stop the rest from being processed.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER LunName
    Name of the LUN to unmap from the host. Validated against existing LUNs and supports tab completion. Mutually exclusive with LunId.

.PARAMETER LunId
    Id of the LUN to unmap from the host. Validated against existing LUNs, no tab completion. Mutually exclusive with LunName.

.PARAMETER HostName
    Name of the host to unmap the LUN from. Validated against existing hosts and supports tab completion. Mutually exclusive with HostId.

.PARAMETER HostId
    Id of the host to unmap the LUN from. Validated against existing hosts, no tab completion. Mutually exclusive with HostName.

.PARAMETER VstoreId
    Optional vStore ID used to scope the mapping operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Remove-DMmapLunFromHost -LunName 'data-lun' -HostName 'esx01' -WhatIf

    Shows what would happen if data-lun were unmapped from esx01.

.EXAMPLE
    PS> Remove-DMmapLunFromHost -LunId '1' -HostId '3' -Confirm:$false

    Unmaps LUN 1 from host 3 by Id.

.NOTES
    Filename: Remove-DMmapLunFromHost.ps1
#>
function Remove-DMmapLunFromHost {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'LunByName_HostByName')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, ParameterSetName = 'LunByName_HostByName', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'LunByName_HostById', ValueFromPipelineByPropertyName = $true)]
        [Alias('Name')]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                $matchingItems = @(Get-DMlun -WebSession $session -Name $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "LunName is ambiguous because more than one LUN is named '$_'."
                }
                throw 'Invalid LunName.'
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMlun -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$LunName,

        [Parameter(Mandatory = $true, ParameterSetName = 'LunById_HostByName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'LunById_HostById')]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                $matchingItems = @(Get-DMlun -WebSession $session -Id $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                throw 'Invalid LunId.'
            })]
        [string]$LunId,

        [Parameter(Mandatory = $true, ParameterSetName = 'LunByName_HostByName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'LunById_HostByName')]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                $matchingItems = @(Get-DMhost -WebSession $session -Name $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "HostName is ambiguous because more than one host is named '$_'."
                }
                throw 'Invalid HostName.'
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMhost -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$HostName,

        [Parameter(Mandatory = $true, ParameterSetName = 'LunByName_HostById')]
        [Parameter(Mandatory = $true, ParameterSetName = 'LunById_HostById')]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                $matchingItems = @(Get-DMhost -WebSession $session -Id $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                throw 'Invalid HostId.'
            })]
        [string]$HostId,

        [string]$VstoreId
    )

    process {
        try {
            $session = if ($WebSession) {
                $WebSession
            }
            else {
                $script:CurrentOceanstorSession
            }

            switch -Wildcard ($PSCmdlet.ParameterSetName) {
                'LunByName_*' {
                    $lun = @(Get-DMlun -WebSession $session -Name $LunName)[0]
                    if ($null -eq $lun) {
                        throw "Could not resolve 'LunName' - the object may have been removed since parameter validation."
                    }
                }
                'LunById_*' {
                    $lun = @(Get-DMlun -WebSession $session -Id $LunId)[0]
                    if ($null -eq $lun) {
                        throw "Could not resolve 'LunId' - the object may have been removed since parameter validation."
                    }
                }
            }

            switch -Wildcard ($PSCmdlet.ParameterSetName) {
                '*_HostByName' {
                    $hostObject = @(Get-DMhost -WebSession $session -Name $HostName)[0]
                    if ($null -eq $hostObject) {
                        throw "Could not resolve 'HostName' - the object may have been removed since parameter validation."
                    }
                }
                '*_HostById' {
                    $hostObject = @(Get-DMhost -WebSession $session -Id $HostId)[0]
                    if ($null -eq $hostObject) {
                        throw "Could not resolve 'HostId' - the object may have been removed since parameter validation."
                    }
                }
            }

            $body = @{ hostId = $hostObject.Id; lunId = $lun.Id }
            if ($VstoreId) {
                $body.vstoreId = $VstoreId
            }

            if ($PSCmdlet.ShouldProcess("$($lun.Name) <- $($hostObject.Name)", 'Remove LUN-host mapping')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource 'mapping' -BodyData $body
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
