function get-DMPortBond {
    <#
.SYNOPSIS
    To Get Huawei Oceanstor Storage configured Bonds

.DESCRIPTION
    Function to request Huawei Oceanstor Storage configured Bonds

.PARAMETER webSession
    Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

.INPUTS

.OUTPUTS
    returns the Huawei Oceanstor Storage configured Bonds in the system. Return an Array object.

.EXAMPLE

    PS C:\> get-DMPortBond -webSession $session

    OR

    PS C:\> $bonds = get-DMPortBond

.NOTES
    Filename: get-DMPortBond.ps1
    Author: Joao Carmona
    Modified date: 2022-06-23
    Version 0.1

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

    $defaultDisplaySet = "Id", "Name", "Health Status", "Running Status", "Ethernet Ports"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "bond_port" | Select-Object -ExpandProperty data
    $bonds = New-Object System.Collections.ArrayList

    foreach ($tbond in $response) {
        $bondObj = [OceanStorPortBond]::new($tbond, $session)
        [void]$bonds.Add($bondObj)
    }

    $bonds | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $bonds

    return $result
}
