<#
.SYNOPSIS
    Retrieves NVMe over RoCE initiators from the OceanStor device manager.

.DESCRIPTION
    Returns NVMe over RoCE initiators for all hosts, for a specific host, or filtered to free initiators.
    The query can be scoped to a vStore when required by the target system.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the global deviceManager session is used.

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
                    $deviceManager
                }
                $hosts = @(Get-DMhost -WebSession $session)
                $matchingItems = @($hosts | Where-Object Name -EQ $candidate)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "HostName is ambiguous because more than one host is named '$candidate'."
                }
                throw "Invalid HostName. Valid values are: $($hosts.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
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
        $deviceManager
    }
    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]@('Id', 'Type', 'Host Name', 'Running Status', 'Is Free')
    )
    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    if ($HostName) {
        $hostObject = @(Get-DMhost -WebSession $session | Where-Object Name -EQ $HostName)[0]
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

    $queryResult = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource $resource
    $response = @()
    if ($null -ne $queryResult -and $null -ne $queryResult.PSObject.Properties['data']) {
        $response = @($queryResult.data)
    }
    $result = @()
    foreach ($initiator in $response) {
        $item = [OceanstorHostinitiatorNVMe]::new($initiator, $session)
        $item | Add-Member MemberSet PSStandardMembers $standardMembers -Force
        $result += $item
    }
    return $result
}
