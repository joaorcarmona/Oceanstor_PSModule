function New-DMHost {
    <#
    .SYNOPSIS
        Creates an OceanStor host.

    .DESCRIPTION
        Creates a host object in OceanStor with a name, operating system type, optional description, and optional vStore scope.
        The cmdlet returns the created host object when the API call succeeds.

    .PARAMETER WebSession
        Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

    .PARAMETER Name
        Name of the host to create. The value must be 1 to 255 characters and may contain letters, numbers, underscores, periods, or hyphens.

    .PARAMETER OperatingSystem
        Host operating system type. The value is translated to the OceanStor host OS code before the create request is sent.

    .PARAMETER Description
        Optional description for the host. The value can be up to 255 characters.

    .PARAMETER VstoreId
        Optional vStore ID used to scope the host creation operation.

    .INPUTS
        System.Management.Automation.PSCustomObject

    .OUTPUTS
        OceanStorHost
        Returns the created host object on success, or the API error object on failure.

    .EXAMPLE
        PS> New-DMHost -Name 'host01' -OperatingSystem 'VMware ESX' -Description 'Production ESXi host'

        Creates host01 with the VMware ESX operating system type.

    .NOTES
        Filename: New-DMHost.ps1
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
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
        $script:CurrentOceanstorSession
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

    if ($PSCmdlet.ShouldProcess($Name, 'Create host')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'host' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        if ($response.error.Code -eq 0) {
            return [OceanStorHost]::new($response.data, $session)
        }
        return $response.error
    }
}
