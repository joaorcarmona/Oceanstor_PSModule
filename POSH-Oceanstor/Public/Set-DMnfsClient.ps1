<#
.SYNOPSIS
    Modifies an OceanStor NFS share client.

.DESCRIPTION
    Updates an existing NFS share authorization client via PUT NFS_SHARE_AUTH_CLIENT/{id}.
    ALLSQUASH and ROOTSQUASH are mandatory on the API's modify call, so the client's
    current values are fetched and re-sent when Access/AllSquash/RootSquash are not
    explicitly specified.

    Accepts multiple clients from the pipeline by property name. Each client is resolved
    and modified independently: a failure is reported as a non-terminating error and
    does not stop the rest from being processed.

.PARAMETER WebSession
    Optional session returned by Connect-deviceManager. The module's cached $script:CurrentOceanstorSession session is used by default.

.PARAMETER ClientName
    Name of the NFS share client to modify. Validated against existing OceanStor NFS file clients.

.PARAMETER Access
    New access permission: ReadOnly, ReadWrite, or None.

.PARAMETER AllSquash
    New permission constraint: AllSquash or NoAllSquash.

.PARAMETER RootSquash
    New root permission constraint: RootSquash or NoRootSquash.

.PARAMETER AnonymousId
    Anonymous user ID.

.PARAMETER VstoreId
    Optional vStore ID used to scope the modify operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Set-DMnfsClient -ClientName '10.10.10.10' -Access ReadWrite -Confirm:$false

.NOTES
    Filename: Set-DMnfsClient.ps1
#>
function Set-DMnfsClient {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Alias('Name')]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMnfsFileClient -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$ClientName,

        [ValidateSet('ReadOnly', 'ReadWrite', 'None')]
        [string]$Access,

        [ValidateSet('AllSquash', 'NoAllSquash')]
        [string]$AllSquash,

        [ValidateSet('RootSquash', 'NoRootSquash')]
        [string]$RootSquash,

        [uint32]$AnonymousId,

        [string]$VstoreId
    )

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

            $hasChanges = $PSBoundParameters.ContainsKey('Access') -or
                $PSBoundParameters.ContainsKey('AllSquash') -or
                $PSBoundParameters.ContainsKey('RootSquash') -or
                $PSBoundParameters.ContainsKey('AnonymousId')
            if (-not $hasChanges) {
                throw 'Specify at least one of Access, AllSquash, RootSquash, AnonymousId.'
            }

            $clients = @(Get-DMnfsFileClient -WebSession $session)
            $matchingItems = @($clients | Where-Object Name -CEQ $ClientName)
            if ($matchingItems.Count -ne 1) {
                if ($matchingItems.Count -gt 1) {
                    throw "ClientName '$ClientName' is ambiguous."
                }
                throw "Invalid ClientName '$ClientName'. Valid values are: $($clients.Name -join ', ')"
            }
            $client = $matchingItems[0]

            $currentResponse = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "NFS_SHARE_AUTH_CLIENT/$($client.Id)"
            $currentResponse = $currentResponse | Assert-DMApiSuccess
            $current = $currentResponse.data

            $body = @{
                ID         = $client.Id
                ACCESSVAL  = if ($PSBoundParameters.ContainsKey('Access')) {
                    switch ($Access) { 'ReadOnly' { 0 }; 'ReadWrite' { 1 }; 'None' { 5 } }
                }
                else {
                    [int]$current.ACCESSVAL
                }
                ALLSQUASH  = if ($PSBoundParameters.ContainsKey('AllSquash')) {
                    switch ($AllSquash) { 'AllSquash' { 0 }; 'NoAllSquash' { 1 } }
                }
                else {
                    [int]$current.ALLSQUASH
                }
                ROOTSQUASH = if ($PSBoundParameters.ContainsKey('RootSquash')) {
                    switch ($RootSquash) { 'RootSquash' { 0 }; 'NoRootSquash' { 1 } }
                }
                else {
                    [int]$current.ROOTSQUASH
                }
            }

            if ($PSBoundParameters.ContainsKey('AnonymousId')) {
                $body.ANONYMOUSID = $AnonymousId
            }
            if ($VstoreId) {
                $body.vstoreId = $VstoreId
            }

            if (-not $PSCmdlet.ShouldProcess($ClientName, 'Modify NFS share client')) {
                return
            }

            $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource "NFS_SHARE_AUTH_CLIENT/$($client.Id)" -BodyData $body
            $response = $response | Assert-DMApiSuccess
            return $response.error
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
