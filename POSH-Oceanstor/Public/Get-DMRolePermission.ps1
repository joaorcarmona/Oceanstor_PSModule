function Get-DMRolePermission {
    <#
    .SYNOPSIS
        Gets permissions available for OceanStor user-defined roles.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject[]])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true)]
        [string]$RoleOwnerGroup
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $encodedRoleOwnerGroup = [uri]::EscapeDataString($RoleOwnerGroup)
    $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "querying_permissions_available?roleOwnerGroup=$encodedRoleOwnerGroup" |
        Select-DMResponseData
    return @($response | ForEach-Object { [OceanStorRolePermission]::new($_, $session) })
}
