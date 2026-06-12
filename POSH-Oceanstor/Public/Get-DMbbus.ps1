function Get-DMbbus {
    <#
    .SYNOPSIS
        To Get Huawei Oceanstor Storage System BBU
    .DESCRIPTION
        Function to request Huawei Oceanstor Storage System BBU
    .PARAMETER webSession
        Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used
    .INPUTS
        System.Management.Automation.PSCustomObject

        You can pipe an OceanStor session object to WebSession.
    .OUTPUTS
        OceanstorBBU

        Returns backup battery unit objects.
    .EXAMPLE

        PS C:\> Get-DMbbus -webSession $session

        OR

        PS C:\> $bbus = Get-DMbbus
    .NOTES
        Filename: Get-DMbbus.ps1
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

    $defaultDisplaySet = "Id", "PSU Location", "Health Status", "Running Status", "Remaining Life"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "backup_power" | Select-Object -ExpandProperty data
    $bbus = New-Object System.Collections.ArrayList

    foreach ($bbu in $response) {
        $bbu = [OceanstorBBU]::new($bbu, $session)
        [void]$bbus.Add($bbu)
    }

    $bbus | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $bbus

    return $result
}
