<#
.SYNOPSIS
    Removes one or more OceanStor LUNs from a protection group.

.DESCRIPTION
    Disassociates a LUN from a protection group via the OceanStor protection group interface. The
    protection group can be identified by Name or by Id; the LUN(s) can be identified by Name (one
    LUN), Id (one or more, comma-separated), or a LUN object piped in from Get-DMLun. Name and Id
    are mutually exclusive for the same object, enforced by PowerShell parameter sets. Name
    parameters are validated at parameter-binding time with tab completion; Id parameters are
    validated too, but have no tab completion.

    Note: -LunName cannot itself be pipeline-bound by property, since the protection group's own
    -Name parameter would collide with a piped object's Name property (PowerShell rejects a
    parameter alias that matches another parameter's literal name). Piping a LUN in uses the
    whole-object pipeline instead (see -InputObject).

    When exactly one LUN Id resolves (LunName, a single LunId, or one LUN piped in), the single-LUN
    "remove" interface is used. When -LunId resolves to more than one Id, the batch "remove"
    interface is used instead, sending all of them in a single REST call.

    Accepts multiple LUN objects from the pipeline. Each LUN is removed independently: a REST error
    is reported as a non-terminating error and does not stop the rest from being processed.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER Name
    Name of the protection group to remove the LUN(s) from. Validated against existing protection groups and supports tab completion. Mutually exclusive with Id.

.PARAMETER Id
    Id of the protection group to remove the LUN(s) from. Validated against existing protection groups, no tab completion. Mutually exclusive with Name.

.PARAMETER LunName
    Name of a single LUN to remove. Validated against existing LUNs and supports tab completion. Mutually exclusive with LunId and InputObject.

.PARAMETER LunId
    Id of one or more LUNs to remove, either as native PowerShell array syntax (-LunId 1,2,3) or a single comma-separated string (-LunId "1,2,3"). Each Id is validated against existing LUNs, no tab completion. Mutually exclusive with LunName and InputObject.

.PARAMETER InputObject
    A LUN object (from Get-DMLun) piped in to remove. Mutually exclusive with LunName and LunId.

.INPUTS
    System.Management.Automation.PSCustomObject
    OceanstorLunv3, OceanstorLunv6

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object (single LUN) or an array of per-LUN result objects (multiple LUN Ids).

.EXAMPLE
    PS> Get-DMLun 'production-db' | Remove-DMLunFromProtectionGroup -Id 5

    Removes production-db from protection group 5, using the single-LUN interface.

.EXAMPLE
    PS> Remove-DMLunFromProtectionGroup -Name 'pg-production' -LunName 'production-db'

.EXAMPLE
    PS> Remove-DMLunFromProtectionGroup -Name 'pg-production' -LunId 12,13,14

    Removes three LUNs from pg-production in a single batch REST call.

.NOTES
    Filename: Remove-DMLunFromProtectionGroup.ps1
#>
function Remove-DMLunFromProtectionGroup {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ProtectionGroupByName_LunByName')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, ParameterSetName = 'ProtectionGroupByName_LunByName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ProtectionGroupByName_LunById')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ProtectionGroupByName_LunByObject')]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
                $matchingItems = @(Get-DMProtectionGroup -WebSession $session | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) { return $true }
                if ($matchingItems.Count -gt 1) { throw "Name is ambiguous because more than one protection group is named '$_'." }
                throw 'Invalid Name.'
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMProtectionGroup -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'ProtectionGroupById_LunByName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ProtectionGroupById_LunById')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ProtectionGroupById_LunByObject')]
        [ValidateScript({
                $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
                $matchingItems = @(Get-DMProtectionGroup -WebSession $session -Id $_)
                if ($matchingItems.Count -eq 1) { return $true }
                throw 'Invalid Id.'
            })]
        [string]$Id,

        [Parameter(Mandatory = $true, ParameterSetName = 'ProtectionGroupByName_LunByName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ProtectionGroupById_LunByName')]
        [ValidateScript({
                $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
                $matchingItems = @(Get-DMlun -WebSession $session | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) { return $true }
                if ($matchingItems.Count -gt 1) { throw "LunName is ambiguous because more than one LUN is named '$_'." }
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

        [Parameter(Mandatory = $true, ParameterSetName = 'ProtectionGroupByName_LunById')]
        [Parameter(Mandatory = $true, ParameterSetName = 'ProtectionGroupById_LunById')]
        [ValidateScript({
                $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
                $ids = ($_ -join ',') -split ',' | Where-Object { $_ }
                foreach ($lunId in $ids) {
                    $matchingItems = @(Get-DMlun -WebSession $session -Id $lunId)
                    if ($matchingItems.Count -ne 1) {
                        throw "Invalid LunId '$lunId'."
                    }
                }
                return $true
            })]
        [string[]]$LunId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ProtectionGroupByName_LunByObject', ValueFromPipeline = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'ProtectionGroupById_LunByObject', ValueFromPipeline = $true)]
        [psobject]$InputObject
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
                'ProtectionGroupByName_*' {
                    $protectionGroup = @(Get-DMProtectionGroup -WebSession $session | Where-Object Name -EQ $Name)[0]
                    if ($null -eq $protectionGroup) { throw "Could not resolve 'Name' - the object may have been removed since parameter validation." }
                }
                'ProtectionGroupById_*' {
                    $protectionGroup = @(Get-DMProtectionGroup -WebSession $session -Id $Id)[0]
                    if ($null -eq $protectionGroup) { throw "Could not resolve 'Id' - the object may have been removed since parameter validation." }
                }
            }

            $lunIds = @(switch -Wildcard ($PSCmdlet.ParameterSetName) {
                '*_LunByName' {
                    $lun = @(Get-DMlun -WebSession $session | Where-Object Name -EQ $LunName)[0]
                    if ($null -eq $lun) { throw "Could not resolve 'LunName' - the object may have been removed since parameter validation." }
                    @($lun.Id)
                }
                '*_LunById' {
                    @(($LunId -join ',') -split ',' | Where-Object { $_ })
                }
                '*_LunByObject' {
                    if ($null -eq $InputObject.Id) { throw "InputObject does not have an 'Id' property; pipe a LUN object from Get-DMLun." }
                    @($InputObject.Id)
                }
            })

            if ($lunIds.Count -le 1) {
                $resource = "protectgroup/associate?protectGroupId=$($protectionGroup.Id)&ASSOCIATEOBJTYPE=11&ASSOCIATEOBJID=$($lunIds[0])"
                if ($PSCmdlet.ShouldProcess("$($lunIds[0]) <- $($protectionGroup.Name)", 'Remove LUN from protection group')) {
                    $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource -ApiV2
                    $response = $response | Assert-DMApiSuccess
                    return $response.error
                }
            }
            else {
                $body = @($lunIds | ForEach-Object {
                        @{ ID = $protectionGroup.Id; ASSOCIATEOBJTYPE = 11; ASSOCIATEOBJID = $_ }
                    })
                if ($PSCmdlet.ShouldProcess("$($lunIds -join ', ') <- $($protectionGroup.Name)", 'Remove LUNs from protection group')) {
                    $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource 'protectgroup/associate/batch' -BodyData $body
                    $response = $response | Assert-DMApiSuccess
                    return $response.data
                }
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}