<#
.SYNOPSIS
    Maps an OceanStor LUN group directly to a host group.

.DESCRIPTION
    Creates a direct host-group-to-LUN-group mapping via the OceanStor v2 mapping interface. The
    LUN group and the host group can each be identified by Name or by Id; Name and Id are mutually
    exclusive for the same object, enforced by PowerShell parameter sets (supplying both
    -LunGroupName and -LunGroupId, or both -HostGroupName and -HostGroupId, is a parameter-binding
    error). Both Name parameters are validated at parameter-binding time with tab completion; both
    Id parameters are validated too, but have no tab completion.
    This does not target an existing named mapping view -- the OceanStor REST API's legacy
    mappingview/CREATE_ASSOCIATE endpoint only accepts one group association at a time paired to
    a pre-created view. The recommended v2 mapping interface used here creates (or extends) the
    underlying mapping view implicitly from the host-group/LUN-group pair alone, so there is no
    -MappingViewName parameter.
    The cmdlet supports -WhatIf and -Confirm.

    Accepts multiple LUN groups from the pipeline by property name (Name only; Id is not
    pipeline-bound). Each is resolved and mapped to the same host group independently: a REST
    error is reported as a non-terminating error and does not stop the rest from being processed.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER LunGroupName
    Name of the LUN group to map to the host group. Validated against existing LUN groups and supports tab completion. Mutually exclusive with LunGroupId.

.PARAMETER LunGroupId
    Id of the LUN group to map to the host group. Validated against existing LUN groups, no tab completion. Mutually exclusive with LunGroupName.

.PARAMETER HostGroupName
    Name of the host group to map the LUN group to. Validated against existing host groups and supports tab completion. Mutually exclusive with HostGroupId.

.PARAMETER HostGroupId
    Id of the host group to map the LUN group to. Validated against existing host groups, no tab completion. Mutually exclusive with HostGroupName.

.PARAMETER VstoreId
    Optional vStore ID used to scope the mapping operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    OceanStorMappingView
    Returns the created mapping view object on success.

.EXAMPLE
    PS> Add-DMmapLunGroupToHostGroup -LunGroupName 'production-luns' -HostGroupName 'esx-cluster' -WhatIf

    Shows what would happen if production-luns were mapped to esx-cluster.

.EXAMPLE
    PS> Add-DMmapLunGroupToHostGroup -LunGroupId '12' -HostGroupId '3'

    Maps LUN group 12 to host group 3 by Id.

.NOTES
    Filename: Add-DMmapLunGroupToHostGroup.ps1
#>
function Add-DMmapLunGroupToHostGroup {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'LunGroupByName_HostGroupByName')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, ParameterSetName = 'LunGroupByName_HostGroupByName', ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'LunGroupByName_HostGroupById', ValueFromPipelineByPropertyName = $true)]
        [Alias('Name')]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                $matchingItems = @(Get-DMlunGroup -WebSession $session -Name $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "LunGroupName is ambiguous because more than one LUN group is named '$_'."
                }
                throw 'Invalid LunGroupName.'
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMlunGroup -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$LunGroupName,

        [Parameter(Mandatory = $true, ParameterSetName = 'LunGroupById_HostGroupByName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'LunGroupById_HostGroupById')]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                $matchingItems = @(Get-DMlunGroup -WebSession $session -Id $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                throw 'Invalid LunGroupId.'
            })]
        [string]$LunGroupId,

        [Parameter(Mandatory = $true, ParameterSetName = 'LunGroupByName_HostGroupByName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'LunGroupById_HostGroupByName')]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                $matchingItems = @(Get-DMhostGroup -WebSession $session -Name $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "HostGroupName is ambiguous because more than one host group is named '$_'."
                }
                throw 'Invalid HostGroupName.'
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMhostGroup -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$HostGroupName,

        [Parameter(Mandatory = $true, ParameterSetName = 'LunGroupByName_HostGroupById')]
        [Parameter(Mandatory = $true, ParameterSetName = 'LunGroupById_HostGroupById')]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                $matchingItems = @(Get-DMhostGroup -WebSession $session -Id $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                throw 'Invalid HostGroupId.'
            })]
        [string]$HostGroupId,

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
                'LunGroupByName_*' {
                    $lunGroup = @(Get-DMlunGroup -WebSession $session -Name $LunGroupName)[0]
                    if ($null -eq $lunGroup) {
                        throw "Could not resolve 'LunGroupName' - the object may have been removed since parameter validation."
                    }
                }
                'LunGroupById_*' {
                    $lunGroup = @(Get-DMlunGroup -WebSession $session -Id $LunGroupId)[0]
                    if ($null -eq $lunGroup) {
                        throw "Could not resolve 'LunGroupId' - the object may have been removed since parameter validation."
                    }
                }
            }

            switch -Wildcard ($PSCmdlet.ParameterSetName) {
                '*_HostGroupByName' {
                    $hostGroup = @(Get-DMhostGroup -WebSession $session -Name $HostGroupName)[0]
                    if ($null -eq $hostGroup) {
                        throw "Could not resolve 'HostGroupName' - the object may have been removed since parameter validation."
                    }
                }
                '*_HostGroupById' {
                    $hostGroup = @(Get-DMhostGroup -WebSession $session -Id $HostGroupId)[0]
                    if ($null -eq $hostGroup) {
                        throw "Could not resolve 'HostGroupId' - the object may have been removed since parameter validation."
                    }
                }
            }

            $body = @{ hostGroupId = $hostGroup.Id; lunGroupId = $lunGroup.Id }
            if ($VstoreId) {
                $body.vstoreId = $VstoreId
            }

            if ($PSCmdlet.ShouldProcess("$($lunGroup.Name) -> $($hostGroup.Name)", 'Map LUN group to host group')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'mapping' -BodyData $body -ApiV2
                $response = $response | Assert-DMApiSuccess
                return [OceanStorMappingView]::new($response.data, $session)
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
