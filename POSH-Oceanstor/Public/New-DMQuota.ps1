function New-DMQuota {
    <#
    .SYNOPSIS
        Creates an OceanStor directory, user, or user-group quota.

    .DESCRIPTION
        Creates a quota on a file system or dtree via the FS_QUOTA resource. At least
        one of SpaceSoftLimit, SpaceHardLimit, FileSoftLimit, FileHardLimit must be
        supplied, matching the API's own requirement. Hard limits must exceed soft
        limits when both are given for the same dimension.

    .PARAMETER WebSession
        Optional session returned by Connect-deviceManager. The module's cached $script:CurrentOceanstorSession session is used by default.

    .PARAMETER FileSystemName
        File system to create the quota on (directory quota's default target, or the parent of DtreeName).

    .PARAMETER DtreeName
        Dtree (within FileSystemName) to create a directory quota on. Omit for a file-system-level directory quota.

    .PARAMETER QuotaType
        Directory (default), User, or UserGroup.

    .PARAMETER AccountName
        User or user-group name. Mandatory when QuotaType is User or UserGroup.

    .PARAMETER AccountType
        Local or Domain. Mandatory when QuotaType is User or UserGroup.

    .PARAMETER SpaceSoftLimit
        Space soft quota. Accepts MB, GB, or TB suffix (e.g. '500MB', '1,5TB') or a raw byte count. Must be a multiple of 1 MB.

    .PARAMETER SpaceHardLimit
        Space hard quota. Same format as SpaceSoftLimit.

    .PARAMETER FileSoftLimit
        Soft quota of file count.

    .PARAMETER FileHardLimit
        Hard quota of file count.

    .PARAMETER VstoreId
        Optional vStore ID, required in multi-vStore scenarios.

    .INPUTS
        System.Management.Automation.PSCustomObject

    .OUTPUTS
        OceanstorQuota

    .EXAMPLE
        PS> New-DMQuota -FileSystemName 'fs01' -SpaceHardLimit 500GB

    .EXAMPLE
        PS> New-DMQuota -FileSystemName 'fs01' -DtreeName 'project-a' -QuotaType User -AccountName 'jdoe' -AccountType Local -SpaceHardLimit 100GB
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    [OutputType('OceanstorQuota')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMFileSystem -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$FileSystemName,

        [ValidateNotNullOrEmpty()]
        [string]$DtreeName,

        [ValidateSet('Directory', 'User', 'UserGroup')]
        [string]$QuotaType = 'Directory',

        [ValidateNotNullOrEmpty()]
        [string]$AccountName,

        [ValidateSet('Local', 'Domain')]
        [string]$AccountType,

        [ValidateNotNullOrEmpty()]
        [object]$SpaceSoftLimit,

        [ValidateNotNullOrEmpty()]
        [object]$SpaceHardLimit,

        [ValidateRange(1, 2000000000)]
        [uint32]$FileSoftLimit,

        [ValidateRange(1, 2000000000)]
        [uint32]$FileHardLimit,

        [string]$VstoreId
    )

    begin {
        $hasLimit = $PSBoundParameters.ContainsKey('SpaceSoftLimit') -or
            $PSBoundParameters.ContainsKey('SpaceHardLimit') -or
            $PSBoundParameters.ContainsKey('FileSoftLimit') -or
            $PSBoundParameters.ContainsKey('FileHardLimit')
        if (-not $hasLimit) {
            throw 'Specify at least one of SpaceSoftLimit, SpaceHardLimit, FileSoftLimit, FileHardLimit.'
        }
        if ($QuotaType -ne 'Directory' -and (-not $AccountName -or -not $AccountType)) {
            throw 'AccountName and AccountType are mandatory when QuotaType is User or UserGroup.'
        }
    }

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

            $fileSystems = @(Get-DMFileSystem -WebSession $session)
            $matchingFileSystems = @($fileSystems | Where-Object Name -CEQ $FileSystemName)
            if ($matchingFileSystems.Count -ne 1) {
                if ($matchingFileSystems.Count -gt 1) {
                    throw "FileSystemName '$FileSystemName' is ambiguous."
                }
                throw "Invalid FileSystemName '$FileSystemName'. Valid values are: $($fileSystems.Name -join ', ')"
            }
            $fileSystem = $matchingFileSystems[0]

            $body = @{
                PARENTTYPE = 40
                PARENTID   = $fileSystem.Id
                QUOTATYPE  = switch ($QuotaType) { 'Directory' { 1 }; 'User' { 2 }; 'UserGroup' { 3 } }
            }

            if ($DtreeName) {
                $dtrees = @((Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "QUOTATREE?PARENTID=$($fileSystem.Id)").data)
                $matchingDtrees = @($dtrees | Where-Object NAME -CEQ $DtreeName)
                if ($matchingDtrees.Count -ne 1) {
                    if ($matchingDtrees.Count -gt 1) {
                        throw "DtreeName '$DtreeName' is ambiguous."
                    }
                    throw "Invalid DtreeName '$DtreeName'. Valid values are: $($dtrees.NAME -join ', ')"
                }
                $body.PARENTTYPE = 16445
                $body.PARENTID = $matchingDtrees[0].ID
            }

            if ($AccountName) {
                $body.USRGRPOWNERNAME = $AccountName
                $body.USRGRPTYPE = if ($AccountType -eq 'Domain') { 2 } else { 1 }
            }

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

            if ($VstoreId) {
                $body.vstoreId = $VstoreId
            }

            $target = if ($DtreeName) { "$FileSystemName/$DtreeName" } else { $FileSystemName }
            if (-not $PSCmdlet.ShouldProcess($target, "Create $QuotaType quota")) {
                return
            }

            $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'FS_QUOTA' -BodyData $body
            $response = $response | Assert-DMApiSuccess
            return [OceanstorQuota]::new($response.data, $session)
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
