function Get-DMPortBond {
    <#
.SYNOPSIS
    To Get Huawei Oceanstor Storage configured Bonds

.DESCRIPTION
    Function to request Huawei Oceanstor Storage configured Bonds

.PARAMETER webSession
    Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

.INPUTS
    System.Management.Automation.PSCustomObject

    You can pipe an OceanStor session object to WebSession.

.OUTPUTS
    OceanStorPortBond

    Returns bonded Ethernet port objects.

.EXAMPLE

    PS C:\> Get-DMPortBond -webSession $session

    OR

    PS C:\> $bonds = Get-DMPortBond

.NOTES
    Filename: Get-DMPortBond.ps1

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

    $defaultDisplaySet = "Id", "Name", "Health Status", "Running Status", "Ethernet Ports"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "bond_port" | Select-DMResponseData
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
