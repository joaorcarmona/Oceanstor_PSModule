function New-DMHost {
    <#
    .SYNOPSIS
        Creates a Huawei OceanStor host.
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
        [ValidateSet('Linux', 'Windows', 'Solaris', 'HP-UX', 'AIX', 'XenServer', 'Mac OS', 'VMware ESX', 'LINUX_VIS', 'Windows Server 2012', 'Oracle VM', 'OpenVMS', 'Oracle_VM_Server_for_x86', 'Oracle_VM_Server_for_SPARC')]
        [string]$OperatingSystem = 'Linux',

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
    $operatingSystemValue = @{
        'Linux'                      = 0
        'Windows'                    = 1
        'Solaris'                    = 2
        'HP-UX'                      = 3
        'AIX'                        = 4
        'XenServer'                  = 5
        'Mac OS'                     = 6
        'VMware ESX'                 = 7
        'LINUX_VIS'                  = 8
        'Windows Server 2012'        = 9
        'Oracle VM'                  = 10
        'OpenVMS'                    = 11
        'Oracle_VM_Server_for_x86'   = 12
        'Oracle_VM_Server_for_SPARC' = 13
    }[$OperatingSystem]
    $body = @{
        TYPE            = 21
        NAME            = $Name
        OPERATIONSYSTEM = $operatingSystemValue
    }
    if ($PSBoundParameters.ContainsKey('Description')) {
        $body.DESCRIPTION = $Description
    }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }

    $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'host' -BodyData $body
    if ($response.error.Code -eq 0) {
        return [OceanStorHost]::new($response.data, $session)
    }

    return $response.error
}
