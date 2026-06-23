function Get-DMLunsbyFilter {
    <#
    .SYNOPSIS
        Searches for LUNs by a property filter.

    .DESCRIPTION
        Searches for LUNs whose specified property equals the supplied keyword.
        When the filter matches a known API field (Name, Id, WWN, Description),
        the query is pushed server-side so only matching rows are transferred.
        Other property names fall back to a client-side exact match.

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

    .PARAMETER Filter
        Mandatory property name to filter against. The value must be a valid LUN object property.

    .PARAMETER Keyword
        Mandatory value to match against the chosen property. The comparison is an exact match.

    .INPUTS
        System.Management.Automation.PSCustomObject

        You can pipe an OceanStor session object to WebSession and provide filter values by property name.

    .OUTPUTS
        OceanstorLunv3
        OceanstorLunv6

        Returns LUN objects matching the requested property filter and keyword.

    .EXAMPLE

        PS C:\> Get-DMLunsbyFilter -webSession $session -Filter WWN -Keyword "6a08cf810075766e1efc050700000005"

        OR

        PS C:\> $luns = Get-DMLunsbyFilter -Filter Name -Keyword "finance"

    .NOTES
        Filename: Get-DMLunsbyFilter.ps1

    .LINK
    #>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipelineByPropertyName = $True, Position = 1, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Filter,
        [Parameter(ValueFromPipelineByPropertyName = $True, Position = 2, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Keyword
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $deviceManager
    }

    # Map friendly property names to API field names for server-side filtering
    $PropertyToApiField = @{
        'Name'              = 'NAME'
        'Id'                = 'ID'
        'WWN'               = 'WWN'
        'Description'       = 'DESCRIPTION'
        'Storage Pool Name' = 'PARENTNAME'
    }

    $apiField = $PropertyToApiField[$Filter]
    if ($apiField) {
        $resource = "lun?filter=$($apiField):$Keyword"
    }
    else {
        $resource = "lun"
    }

    $defaultDisplaySet = "Id", "Name", "Health Status", "Lun Size", "WWN"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource $resource | Select-Object -ExpandProperty data
    $StorageLuns = New-Object System.Collections.ArrayList

    $StorageVersion = $session.version.Substring(0, 2)

    if ($storageVersion -eq "V6") {
        $LunObjectClass = "OceanstorLunv6"
    }
    else {
        $LunObjectClass = "OceanstorLunv3"
    }

    foreach ($tlun in $response) {
        $lun = New-Object -TypeName $LunObjectClass -ArgumentList $tlun, $session
        [void]$StorageLuns.Add($lun)
    }

    if (-not $apiField) {
        $StorageLuns = @($StorageLuns | Where-Object $Filter -eq $Keyword)
    }

    $StorageLuns | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    return $StorageLuns
}
