function Get-DMlunByWWN {
    <#
    .SYNOPSIS
        Searches for a LUN by its WWN.

    .DESCRIPTION
        Searches for a LUN whose WWN equals the supplied value. The filter is
        pushed server-side so only the matching row is transferred from the array.

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .PARAMETER WWN
        Mandatory LUN WWN to search for. The comparison is an exact match.

    .INPUTS
        System.Management.Automation.PSCustomObject

        You can pipe an OceanStor session object to WebSession and provide wwn by property name.

    .OUTPUTS
        OceanstorLunv3
        OceanstorLunv6

        Returns LUN objects whose WWN matches the supplied value. The class depends on the connected OceanStor version.

    .EXAMPLE

        PS C:\> Get-DMlunByWWN -webSession $session -wwn "6a08cf810075766e1efc050700000005"

        OR

        PS C:\> $luns = Get-DMlunByWWN -wwn "6a08cf810075766e1efc050700000005"

    .NOTES
        Filename: Get-DMlunByWWN.ps1

    .LINK
    #>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 1, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$WWN
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $defaultDisplaySet = "Id", "Name", "Health Status", "Lun Size", "WWN"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "lun?filter=WWN:$([uri]::EscapeDataString($WWN))" | Select-DMResponseData
    $StorageLuns = New-Object System.Collections.ArrayList

    $StorageVersion = $session.version.Substring(0, 2)

    if ($storageVersion -eq "V6") {
        $LunObjectClass = "OceanstorLunv6"
    }
    else {
        $LunObjectClass = "OceanstorLunv3"
    }

    foreach ($tlun in $response) {
        $lun = New-Object -TypeName $LunObjectClass -ArgumentList @($tlun, $session)
        [void]$StorageLuns.Add($lun)
    }

    $StorageLuns | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    return $StorageLuns
}

Set-Alias -Name Get-DMlunsByWWN -Value Get-DMlunByWWN
