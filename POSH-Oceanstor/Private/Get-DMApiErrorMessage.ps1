function Get-DMApiErrorMessage {
    <#
    .SYNOPSIS
        Builds the message used when an OceanStor REST response reports a non-zero error code.

    .DESCRIPTION
        Shared by Select-DMResponseData and Invoke-DMPagedRequest (Get-DM* commands) and
        Assert-DMApiSuccess (mutation commands) so all three throw the same message shape for
        the same failure. A small, deliberately narrow table of known Huawei error codes gets an
        actionable hint appended; codes are only added here once verified against this
        codebase's own test fixtures or real hardware, never guessed.

    .PARAMETER ResourceContext
        Optional REST resource path to fold into the message (Invoke-DMPagedRequest's paginated
        calls use this so the failure names which page/resource was being fetched).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object]$Code,

        [AllowEmptyString()]
        [AllowNull()]
        [string]$Description,

        [string]$ResourceContext
    )

    # 1077939726: session/token no longer valid. Already used as the "session expired" test
    # fixture in Get-Hosts.Tests.ps1 and Invoke-DMPagedRequest.Tests.ps1.
    $hints = @{
        1077939726 = 'Your OceanStor session may have expired or been invalidated -- call Connect-deviceManager again.'
    }

    $contextSuffix = if ($ResourceContext) { " for resource '$ResourceContext'" } else { '' }
    $message = "OceanStor API error $($Code)$contextSuffix`: $Description"

    $codeKey = $Code -as [int]
    if ($null -ne $codeKey -and $hints.ContainsKey($codeKey)) {
        $message = "$message. $($hints[$codeKey])"
    }

    return $message
}
