function New-DMLunGroup {
    <#
    .SYNOPSIS
        Creates a Huawei OceanStor LUN group.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateLength(1, 255)]
        [ValidatePattern('^[A-Za-z0-9_.-]+$')]
        [string]$Name,

        [Parameter(Position = 2)]
        [ValidateSet('Other', 'Oracle', 'Exchange', 'SQL Server', 'VMWare', 'Hyper-V')]
        [string]$ApplicationType = 'Other',

        [Parameter(Position = 3)]
        [ValidateLength(0, 255)]
        [string]$Description,

        [string]$VstoreId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $applicationTypeValue = @{
        'Other'      = 0
        'Oracle'     = 1
        'Exchange'   = 2
        'SQL Server' = 3
        'VMWare'     = 4
        'Hyper-V'    = 5
    }[$ApplicationType]
    $body = @{
        NAME      = $Name
        APPTYPE   = $applicationTypeValue
        GROUPTYPE = 0
    }
    if ($PSBoundParameters.ContainsKey('Description')) {
        $body.DESCRIPTION = $Description
    }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }

    $response = invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'lungroup' -BodyData $body
    if ($response.error.Code -eq 0) {
        return [OceanStorLunGroup]::new($response.data, $session)
    }

    return $response.error
}
