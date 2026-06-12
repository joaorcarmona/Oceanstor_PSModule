function Get-DMPortETH {
    <#
.SYNOPSIS
    To Get Huawei Oceanstor Storage configured Ethernet Ports

.DESCRIPTION
    Function to request Huawei Oceanstor Storage configured Ethernet Ports

.PARAMETER webSession
    Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

.INPUTS
    System.Management.Automation.PSCustomObject

    You can pipe an OceanStor session object to WebSession.

.OUTPUTS
    OceanStorPortETH

    Returns Ethernet port objects.

.EXAMPLE

    PS C:\> Get-DMPortETH -webSession $session

    OR

    PS C:\> $ethPorts = Get-DMPortETH

.NOTES
    Filename: Get-DMPortETH.ps1

.LINK
#>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $deviceManager
    }

    $defaultDisplaySet = "Id", "Name", "Health Status", "Running Status", "IPv4 Address"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "eth_port" | Select-Object -ExpandProperty data
    $ethPorts = New-Object System.Collections.ArrayList

    foreach ($peth in $response) {
        $ethpObj = [OceanStorPortETH]::new($peth, $session)
        [void]$ethPorts.Add($ethpObj)
    }

    $ethPorts | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $ethPorts

    return $result
}
