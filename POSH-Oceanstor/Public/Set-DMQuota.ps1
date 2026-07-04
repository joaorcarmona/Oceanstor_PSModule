function Set-DMQuota {
    <#
    .SYNOPSIS
        Modifies an OceanStor quota.

    .DESCRIPTION
        Updates space/file limits on an existing quota via PUT FS_QUOTA/{id}. At least
        one of SpaceSoftLimit, SpaceHardLimit, FileSoftLimit, FileHardLimit must be
        supplied.

        Accepts quotas from the pipeline (e.g. from Get-DMQuota) by property name.
        Each quota is modified independently: a failure is reported as a
        non-terminating error and does not stop the rest from being processed.

    .PARAMETER WebSession
        Optional session returned by Connect-deviceManager. The module's cached $script:CurrentOceanstorSession session is used by default.

    .PARAMETER Id
        Composite quota ID (e.g. '34@4@1') to modify.

    .PARAMETER SpaceSoftLimit
        New space soft quota. Accepts MB, GB, or TB suffix, or a raw byte count.

    .PARAMETER SpaceHardLimit
        New space hard quota. Same format as SpaceSoftLimit.

    .PARAMETER FileSoftLimit
        New soft quota of file count.

    .PARAMETER FileHardLimit
        New hard quota of file count.

    .INPUTS
        System.Management.Automation.PSCustomObject

    .OUTPUTS
        System.Management.Automation.PSCustomObject

    .EXAMPLE
        PS> Get-DMQuota -FileSystemName 'fs01' | Set-DMQuota -SpaceHardLimit 2TB
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [ValidateNotNullOrEmpty()]
        [object]$SpaceSoftLimit,

        [ValidateNotNullOrEmpty()]
        [object]$SpaceHardLimit,

        [ValidateRange(1, 2000000000)]
        [uint32]$FileSoftLimit,

        [ValidateRange(1, 2000000000)]
        [uint32]$FileHardLimit
    )

    begin {
        $hasLimit = $PSBoundParameters.ContainsKey('SpaceSoftLimit') -or
            $PSBoundParameters.ContainsKey('SpaceHardLimit') -or
            $PSBoundParameters.ContainsKey('FileSoftLimit') -or
            $PSBoundParameters.ContainsKey('FileHardLimit')
        if (-not $hasLimit) {
            throw 'Specify at least one of SpaceSoftLimit, SpaceHardLimit, FileSoftLimit, FileHardLimit.'
        }
    }

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

            $body = @{ ID = $Id }

            $spaceSoftBytes = $null
            $spaceHardBytes = $null
            if ($PSBoundParameters.ContainsKey('SpaceSoftLimit')) {
                $spaceSoftBytes = ConvertTo-DMQuotaByte -Capacity $SpaceSoftLimit
                $body.SPACESOFTQUOTA = $spaceSoftBytes
            }
            if ($PSBoundParameters.ContainsKey('SpaceHardLimit')) {
                $spaceHardBytes = ConvertTo-DMQuotaByte -Capacity $SpaceHardLimit
                $body.SPACEHARDQUOTA = $spaceHardBytes
            }
            if ($null -ne $spaceSoftBytes -and $null -ne $spaceHardBytes -and $spaceHardBytes -le $spaceSoftBytes) {
                throw 'SpaceHardLimit must be greater than SpaceSoftLimit.'
            }

            if ($PSBoundParameters.ContainsKey('FileSoftLimit')) {
                $body.FILESOFTQUOTA = $FileSoftLimit
            }
            if ($PSBoundParameters.ContainsKey('FileHardLimit')) {
                $body.FILEHARDQUOTA = $FileHardLimit
            }
            if ($PSBoundParameters.ContainsKey('FileSoftLimit') -and $PSBoundParameters.ContainsKey('FileHardLimit') -and $FileHardLimit -le $FileSoftLimit) {
                throw 'FileHardLimit must be greater than FileSoftLimit.'
            }

            if (-not $PSCmdlet.ShouldProcess($Id, 'Modify quota limits')) {
                return
            }

            $resource = "FS_QUOTA/$([uri]::EscapeDataString($Id))"
            $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource $resource -BodyData $body
            $response = $response | Assert-DMApiSuccess
            return $response.error
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
