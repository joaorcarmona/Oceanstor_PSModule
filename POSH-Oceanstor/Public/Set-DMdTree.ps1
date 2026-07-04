<#
.SYNOPSIS
    Modifies an OceanStor dTree.

.DESCRIPTION
    Updates the name, quota switch, or security style of an existing dTree via
    PUT QUOTATREE/{id}. At least one of NewName, QuotaSwitch, SecurityStyle must be
    supplied.

    Accepts multiple dTrees from the pipeline by property name (all piped dTrees must
    belong to the same FileSystemName). Each dTree is resolved and modified
    independently: a failure is reported as a non-terminating error and does not stop
    the rest from being processed.

.PARAMETER WebSession
    Optional session returned by Connect-deviceManager. The module's cached $script:CurrentOceanstorSession session is used by default.

.PARAMETER FileSystemName
    Name of the file system that contains the dTree. The name is validated against existing OceanStor file systems.

.PARAMETER DTreeName
    Name of the dTree to modify. Valid values are resolved from the selected file system.

.PARAMETER NewName
    New name for the dTree.

.PARAMETER QuotaSwitch
    New quota switch state: enabled or disabled.

.PARAMETER SecurityStyle
    New security style: Native, NTFS, UNIX, or Mixed.

.PARAMETER VstoreId
    Optional vStore ID used to scope the modify operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Set-DMdTree -FileSystemName 'fs01' -DTreeName 'project-a' -QuotaSwitch enabled -Confirm:$false

.NOTES
    Filename: Set-DMdTree.ps1
#>
function Set-DMdTree {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0)]
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

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [Alias('Name')]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                if (-not $fakeBoundParameters.ContainsKey('FileSystemName')) {
                    return
                }
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                $fileSystem = @(Get-DMFileSystem -WebSession $session | Where-Object Name -EQ $fakeBoundParameters.FileSystemName)[0]
                if (-not $fileSystem) {
                    return
                }
                @((Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "QUOTATREE?PARENTID=$($fileSystem.Id)").data).NAME |
                    Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$DTreeName,

        [ValidateLength(1, 255)]
        [string]$NewName,

        [ValidateSet('enabled', 'disabled')]
        [string]$QuotaSwitch,

        [ValidateSet('Native', 'NTFS', 'UNIX', 'Mixed')]
        [string]$SecurityStyle,

        [string]$VstoreId
    )

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

            $hasChanges = $PSBoundParameters.ContainsKey('NewName') -or
                $PSBoundParameters.ContainsKey('QuotaSwitch') -or
                $PSBoundParameters.ContainsKey('SecurityStyle')
            if (-not $hasChanges) {
                throw 'Specify at least one of NewName, QuotaSwitch, SecurityStyle.'
            }

            $fileSystems = @(Get-DMFileSystem -WebSession $session)
            $matchingFileSystems = @($fileSystems | Where-Object Name -EQ $FileSystemName)
            if ($matchingFileSystems.Count -eq 0) {
                throw "Invalid FileSystemName. Valid values are: $($fileSystems.Name -join ', ')"
            }
            if ($matchingFileSystems.Count -gt 1) {
                throw "FileSystemName is ambiguous because more than one file system is named '$FileSystemName'."
            }
            $fileSystem = $matchingFileSystems[0]

            $dtrees = @((Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "QUOTATREE?PARENTID=$($fileSystem.Id)").data)
            $matchingDtrees = @($dtrees | Where-Object NAME -EQ $DTreeName)
            if ($matchingDtrees.Count -eq 0) {
                throw "Invalid DTreeName. Valid values are: $($dtrees.NAME -join ', ')"
            }
            if ($matchingDtrees.Count -gt 1) {
                throw "DTreeName is ambiguous because more than one dTree is named '$DTreeName'."
            }
            $dtree = $matchingDtrees[0]

            $body = @{ ID = $dtree.ID }
            if ($PSBoundParameters.ContainsKey('NewName')) {
                $body.NAME = $NewName
            }
            if ($PSBoundParameters.ContainsKey('QuotaSwitch')) {
                $body.QUOTASWITCH = ($QuotaSwitch -eq 'enabled')
            }
            if ($PSBoundParameters.ContainsKey('SecurityStyle')) {
                $body.securityStyle = switch ($SecurityStyle) {
                    'Native' { 1 }
                    'NTFS' { 2 }
                    'UNIX' { 3 }
                    'Mixed' { 4 }
                }
            }
            if ($VstoreId) {
                $body.vstoreId = $VstoreId
            }

            if (-not $PSCmdlet.ShouldProcess("$FileSystemName/$DTreeName", 'Modify dTree')) {
                return
            }

            $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource "QUOTATREE/$($dtree.ID)" -BodyData $body
            $response = $response | Assert-DMApiSuccess
            return $response.error
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
