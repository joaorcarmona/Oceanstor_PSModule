function Get-DMEnclosures {
    <#
.SYNOPSIS
    To Get Huawei Oceanstor Storage Enclosures

.DESCRIPTION
    Function to request Huawei Oceanstor Enclosures in the system

.PARAMETER webSession
    Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

.INPUTS

.OUTPUTS
    returns the Huawei Oceanstor Storage Enclosures in the system. Return an Array object.

.EXAMPLE

    PS C:\> Get-DMEnclosures -webSession $session

    OR

    PS C:\> $enclosures = Get-DMEnclosures

.NOTES
    Filename: Get-DMEnclosures.ps1
    Author: Joao Carmona
    Modified date: 2022-06-02
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

    $defaultDisplaySet = "Id", "Name", "Health Status", "Running Status", "Model"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "enclosure" | Select-Object -ExpandProperty data
    $enclosures = New-Object System.Collections.ArrayList

    foreach ($tenc in $response) {
        $enc = [OceanStorEnclosure]::new($tenc, $session)
        [void]$enclosures.Add($enc)
    }

    $enclosures | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $enclosures

    return $result
}
