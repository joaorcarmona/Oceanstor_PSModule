<#
.SYNOPSIS
    Retrieves NVMe over RoCE initiators from the OceanStor device manager.

.DESCRIPTION
    Returns NVMe over RoCE initiators for all hosts, for a specific host, or filtered to free initiators.
    The query can be scoped to a vStore when required by the target system.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER HostName
    Name of the host whose NVMe over RoCE initiators should be returned.

.PARAMETER FreeInitiators
    Returns only free NVMe over RoCE initiators that are not assigned to a host.

.PARAMETER VstoreId
    Optional vStore ID used to scope the initiator query.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    OceanstorHostinitiatorNVMe

.EXAMPLE
    PS> Get-DMNvmeInitiator -HostName 'host01'

    Returns the NVMe over RoCE initiators associated with host01.

.EXAMPLE
    PS> Get-DMNvmeInitiator -FreeInitiators

    Returns NVMe over RoCE initiators that are not associated with a host.

.NOTES
    Filename: Get-DMNvmeInitiator.ps1
#>
function Get-DMNvmeInitiator {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, ParameterSetName = 'Host')]
        [ValidateScript({
                $candidate = $_
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                $matchingItems = @(Get-DMhostbyName -WebSession $session -Name $candidate)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "HostName is ambiguous because more than one host is named '$candidate'."
                }
                throw "Invalid HostName '$candidate'. No host with that name exists."
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

        [Parameter(ParameterSetName = 'Free')]
        [switch]$FreeInitiators,

        [string]$VstoreId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $script:CurrentOceanstorSession
    }
    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]@('Id', 'Type', 'Host Name', 'Running Status', 'Is Free')
    )
    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    if ($HostName) {
        $hostObject = @(Get-DMhostbyName -WebSession $session -Name $HostName)[0]
        if ($null -eq $hostObject) { throw "Could not resolve 'hostObject' — the object may have been removed since parameter validation." }
        $parameters = @('ASSOCIATEOBJTYPE=21', "ASSOCIATEOBJID=$($hostObject.Id)")
        if ($VstoreId) {
            $parameters += "vstoreId=$VstoreId"
        }
        $resource = "NVMe_over_RoCE_initiator/associate?$($parameters -join '&')"
    }
    else {
        $parameters = @()
        if ($FreeInitiators) {
            $parameters += 'ISFREE=true'
        }
        if ($VstoreId) {
            $parameters += "vstoreId=$VstoreId"
        }
        $resource = 'NVMe_over_RoCE_initiator'
        if ($parameters.Count -gt 0) {
            $resource += "?$($parameters -join '&')"
        }
    }

    $response = Invoke-DMPagedRequest -WebSession $session -Resource $resource
    $result = @()
    foreach ($initiator in $response) {
        $item = [OceanstorHostinitiatorNVMe]::new($initiator, $session)
        $item | Add-Member MemberSet PSStandardMembers $standardMembers -Force
        $result += $item
    }
    return $result
}
