<#
.SYNOPSIS
    Maps an OceanStor LUN group directly to a host.

.DESCRIPTION
    Creates a direct host-to-LUN-group mapping via the OceanStor v2 mapping interface. Both
    LunGroupName and HostName are validated at parameter-binding time (with tab completion)
    rather than after the cmdlet starts running.
    This does not target an existing named mapping view -- the OceanStor REST API's legacy
    mappingview/CREATE_ASSOCIATE endpoint only accepts host group, LUN group, or port group
    associations paired to a pre-created view. The recommended v2 mapping interface used here
    creates (or extends) the underlying mapping view implicitly from the host/LUN-group pair
    alone, so there is no -MappingViewName parameter.
    The cmdlet supports -WhatIf and -Confirm.

    Accepts multiple LUN groups from the pipeline by property name. Each is resolved and mapped
    to the same host independently: a REST error is reported as a non-terminating error and does
    not stop the rest from being processed.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER LunGroupName
    Name of the LUN group to map to the host. Validated against existing LUN groups and supports tab completion.

.PARAMETER HostName
    Name of the host to map the LUN group to. Validated against existing hosts and supports tab completion.

.PARAMETER VstoreId
    Optional vStore ID used to scope the mapping operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    OceanStorMappingView
    Returns the created mapping view object on success.

.EXAMPLE
    PS> Add-DMmapLunGroupToHost -LunGroupName 'production-luns' -HostName 'esx01' -WhatIf

    Shows what would happen if production-luns were mapped to esx01.

.NOTES
    Filename: Add-DMmapLunGroupToHost.ps1
#>
function Add-DMmapLunGroupToHost {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
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

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                $matchingItems = @(Get-DMhostbyName -WebSession $session -Name $_)
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

            $lunGroup = @(Get-DMlunGroup -WebSession $session -Name $LunGroupName)[0]
            if ($null -eq $lunGroup) {
                throw "Could not resolve 'LunGroupName' - the object may have been removed since parameter validation."
            }

            $hostObject = @(Get-DMhostbyName -WebSession $session -Name $HostName)[0]
            if ($null -eq $hostObject) {
                throw "Could not resolve 'HostName' - the object may have been removed since parameter validation."
            }

            $body = @{ hostId = $hostObject.Id; lunGroupId = $lunGroup.Id }
            if ($VstoreId) {
                $body.vstoreId = $VstoreId
            }

            if ($PSCmdlet.ShouldProcess("$LunGroupName -> $HostName", 'Map LUN group to host')) {
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
