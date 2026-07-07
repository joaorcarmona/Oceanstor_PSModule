function Get-DMQuota {
    <#
    .SYNOPSIS
        Gets OceanStor file system / dtree quotas.

    .DESCRIPTION
        Queries the FS_QUOTA resource. With -FileSystemName or -DtreeName, scopes the
        query to that parent (PARENTTYPE/PARENTID). With no scoping parameter, returns
        every quota on the array. Always paged, since per-user quota counts are
        unbounded.

    .PARAMETER WebSession
        Optional session returned by Connect-deviceManager. The module's cached $script:CurrentOceanstorSession session is used by default.

    .PARAMETER FileSystemName
        File system whose quotas should be returned.

    .PARAMETER DtreeName
        Dtree (within FileSystemName) whose quotas should be returned.

    .PARAMETER QuotaType
        Optional client-side filter: Directory, User, or UserGroup.

    .PARAMETER Id
        Composite quota ID (e.g. '34@4@1') to fetch a single quota directly.

    .INPUTS
        System.Management.Automation.PSCustomObject

    .OUTPUTS
        OceanstorQuota

    .EXAMPLE
        PS> Get-DMQuota -FileSystemName 'fs01'

    .EXAMPLE
        PS> Get-DMQuota -FileSystemName 'fs01' -DtreeName 'project-a' -QuotaType Directory
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByParent')]
    [OutputType('OceanstorQuota')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(ParameterSetName = 'ByParent')]
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

        [Parameter(ParameterSetName = 'ByParent')]
        [string]$DtreeName,

        [ValidateSet('Directory', 'User', 'UserGroup')]
        [string]$QuotaType,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$Id
    )

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

            if ($PSCmdlet.ParameterSetName -eq 'ById') {
                $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "FS_QUOTA/$([uri]::EscapeDataString($Id))"
                $response = $response | Assert-DMApiSuccess
                return [OceanstorQuota]::new($response.data, $session)
            }

            $resourceQuery = 'FS_QUOTA'
            if ($FileSystemName) {
                $fileSystems = @(Get-DMFileSystem -WebSession $session)
                $matchingFileSystems = @($fileSystems | Where-Object Name -CEQ $FileSystemName)
                if ($matchingFileSystems.Count -ne 1) {
                    if ($matchingFileSystems.Count -gt 1) {
                        throw "FileSystemName '$FileSystemName' is ambiguous."
                    }
                    throw "Invalid FileSystemName '$FileSystemName'. Valid values are: $($fileSystems.Name -join ', ')"
                }
                $fileSystem = $matchingFileSystems[0]

                if ($DtreeName) {
                    $dtrees = @((Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "QUOTATREE?PARENTID=$($fileSystem.Id)").data)
                    $matchingDtrees = @($dtrees | Where-Object NAME -CEQ $DtreeName)
                    if ($matchingDtrees.Count -ne 1) {
                        if ($matchingDtrees.Count -gt 1) {
                            throw "DtreeName '$DtreeName' is ambiguous."
                        }
                        throw "Invalid DtreeName '$DtreeName'. Valid values are: $($dtrees.NAME -join ', ')"
                    }
                    $resourceQuery += "?PARENTTYPE=16445&PARENTID=$($matchingDtrees[0].ID)"
                }
                else {
                    $resourceQuery += "?PARENTTYPE=40&PARENTID=$($fileSystem.Id)"
                }
            }

            $response = Invoke-DMPagedRequest -WebSession $session -Resource $resourceQuery
            $quotas = foreach ($item in $response) { [OceanstorQuota]::new($item, $session) }

            if ($QuotaType) {
                $quotas = @($quotas | Where-Object { $_.{Quota Type} -eq $QuotaType })
            }

            return $quotas
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
