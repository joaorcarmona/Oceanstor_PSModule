function Get-DMPortFc {
    <#
.SYNOPSIS
    To Get Huawei Oceanstor Storage configured FC Ports

.DESCRIPTION
    Function to request Huawei Oceanstor Storage configured FC Ports

.PARAMETER webSession
    Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

.INPUTS
    System.Management.Automation.PSCustomObject

    You can pipe an OceanStor session object to WebSession.

.OUTPUTS
    OceanStorPortFC

    Returns Fibre Channel port objects.

.EXAMPLE

    PS C:\> Get-DMPortFc -webSession $session

    OR

    PS C:\> $fcPorts = Get-DMPortFc

.NOTES
    Filename: Get-DMPortFc.ps1

.LINK
#>
    [Cmdletbinding()]
    [OutputType([System.Collections.ArrayList])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $defaultDisplaySet = "Id", "Name", "Health Status", "Running Status", "WWN"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "fc_port" | Select-DMResponseData
    $fcPorts = New-Object System.Collections.ArrayList

    foreach ($pfc in $response) {
        $fcpObj = [OceanStorPortFC]::new($pfc, $session)
        [void]$fcPorts.Add($fcpObj)
    }

    $fcPorts | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $fcPorts

    return $result
}
