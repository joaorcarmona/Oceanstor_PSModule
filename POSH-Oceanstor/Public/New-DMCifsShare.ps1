<#
.SYNOPSIS
    Creates an OceanStor CIFS share.

.DESCRIPTION
    Creates a CIFS share for an existing file system, optionally using a custom share path, description, subtype, offline file mode, SMB behavior flags, vStore scope, or dTree ID.
    The share name and file system name are validated before the create request is sent.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER ShareName
    Name of the CIFS share to create. The value must be 1 to 80 characters and cannot contain characters rejected by the CIFS share interface.

.PARAMETER FileSystemName
    Name of the file system that backs the CIFS share. The name is validated against existing OceanStor file systems.

.PARAMETER SharePath
    Optional share path. When omitted, the cmdlet uses /<FileSystemName>/.

.PARAMETER Description
    Optional description for the CIFS share. The value can be up to 255 characters.

.PARAMETER SubType
    CIFS share subtype. Valid values are Normal, HomeDir, and All.

.PARAMETER OfflineFileMode
    Offline file mode for the CIFS share. Valid values are None, Manual, Documents, and Programs.

.PARAMETER EnableOplock
    Enables or disables opportunistic locking for the CIFS share. Defaults to true.

.PARAMETER EnableNotify
    Enables or disables change notification for the CIFS share. Defaults to true.

.PARAMETER EnableContinuousAvailability
    Enables or disables continuous availability for the CIFS share. Defaults to false.

.PARAMETER EnablePreviousVersions
    Enables or disables previous version visibility for the CIFS share. Defaults to true.

.PARAMETER EnableSnapshotVisible
    Enables or disables snapshot visibility for the CIFS share. Defaults to true.

.PARAMETER EnableSmb3Encryption
    Enables or disables SMB3 encryption for the CIFS share. Defaults to false.

.PARAMETER AllowUnencryptedAccess
    Allows or denies unencrypted access when SMB3 encryption is configured. Defaults to false.

.PARAMETER VstoreId
    Optional vStore ID used to scope the CIFS share creation operation.

.PARAMETER DTreeId
    Optional dTree ID used when the CIFS share targets a dTree.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    OceanStorCIFSShare
    Returns the created CIFS share object on success, or the API error object on failure.

.EXAMPLE
    PS> New-DMCifsShare -ShareName 'share01' -FileSystemName 'fs01'

    Creates a CIFS share named share01 using the default /fs01/ share path.

.EXAMPLE
    PS> New-DMCifsShare -ShareName 'apps' -FileSystemName 'fs01' -SharePath '/fs01/apps/' -OfflineFileMode Programs -EnableSmb3Encryption $true

    Creates an encrypted CIFS share for the apps path and sets the offline file mode to Programs.

.NOTES
    Filename: New-DMCifsShare.ps1
#>
function New-DMCifsShare {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateLength(1, 80)]
        [ValidateScript({
                if ($_ -match '[/\\\[\]:|<>+;,?*=]') {
                    throw 'ShareName contains a character not permitted by the CIFS share interface.'
                }
                if ($_ -match '^\s|\s$' -or $_ -match '^(?i:ipc\$|autohome|~|print\$)$') {
                    throw 'ShareName is reserved or begins/ends with a space.'
                }
                return $true
            })]
        [string]$ShareName,

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                $fileSystems = @(Get-DMFileSystem -WebSession $session)
                $matchingItems = @($fileSystems | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "FileSystemName is ambiguous because more than one file system is named '$_'."
                }
                throw "Invalid FileSystemName. Valid values are: $($fileSystems.Name -join ', ')"
            })]
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

        [Parameter(Position = 3)]
        [ValidateLength(2, 1024)]
        [string]$SharePath,

        [Parameter(Position = 4)]
        [ValidateLength(0, 255)]
        [string]$Description,

        [ValidateSet('Normal', 'HomeDir', 'All')]
        [string]$SubType = 'Normal',

        [ValidateSet('None', 'Manual', 'Documents', 'Programs')]
        [string]$OfflineFileMode = 'Manual',

        [bool]$EnableOplock = $true,

        [bool]$EnableNotify = $true,

        [bool]$EnableContinuousAvailability = $false,

        [bool]$EnablePreviousVersions = $true,

        [bool]$EnableSnapshotVisible = $true,

        [bool]$EnableSmb3Encryption = $false,

        [bool]$AllowUnencryptedAccess = $false,

        [string]$VstoreId,

        [string]$DTreeId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $script:CurrentOceanstorSession
    }
    $fileSystem = @(Get-DMFileSystem -WebSession $session | Where-Object Name -EQ $FileSystemName)[0]
    if ($null -eq $fileSystem) { throw "Could not resolve 'fileSystem' — the object may have been removed since parameter validation." }
    $subTypeValue = @{ Normal = 0; HomeDir = 1; All = 2 }[$SubType]
    $offlineFileModeValue = @{ None = 0; Manual = 1; Documents = 2; Programs = 3 }[$OfflineFileMode]
    $body = @{
        NAME                       = $ShareName
        SHAREPATH                  = if ($SharePath) {
            $SharePath
        }
        else {
            "/$FileSystemName/"
        }
        FSID                       = $fileSystem.Id
        subType                    = $subTypeValue
        OFFLINEFILEMODE            = $offlineFileModeValue
        ENABLEOPLOCK               = $EnableOplock
        ENABLENOTIFY               = $EnableNotify
        ENABLECA                   = $EnableContinuousAvailability
        ENABLESHOWPREVIOUSVERSIONS = $EnablePreviousVersions
        ENABLESHOWSNAPSHOT         = $EnableSnapshotVisible
        smb3EncryptionEnable       = $EnableSmb3Encryption
        unencryptedAccess          = $AllowUnencryptedAccess
    }
    if ($Description) {
        $body.DESCRIPTION = $Description
    }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }
    if ($DTreeId) {
        $body.DTREEID = $DTreeId
    }

    if ($PSCmdlet.ShouldProcess($sharePath, 'Create CIFS share')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'CIFSSHARE' -BodyData $body
        if ($response.error.Code -eq 0) {
            return [OceanStorCIFSShare]::new($response.data, $session)
        }

        return $response.error
    }
}
