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
    #
    # 1077948993: on Dorado 6.1.6, live-verified (docs/network/TODO.md) that PUT lif rejects
    # this as a name collision whenever the mandatory NAME field is resent unchanged alongside
    # any other property change -- an array-side self-collision bug, not a caller mistake. A
    # bare rename (NAME changed, no other field) succeeds; combining NAME with another field
    # never does, whether NAME is omitted, unchanged, or a new value.
    $hints = @{
        1077939726 = 'Your OceanStor session may have expired or been invalidated -- call Connect-deviceManager again.'
        1077948993 = 'This is a known Dorado 6.1.6 firmware limitation: the array rejects this object''s own current name as a duplicate whenever another property is modified in the same call. No client-side body variant avoids it; see docs/network/TODO.md for the live-verified reproduction.'
    }

    $contextSuffix = if ($ResourceContext) { " for resource '$ResourceContext'" } else { '' }
    $message = "OceanStor API error $($Code)$contextSuffix`: $Description"

    $codeKey = $Code -as [int]
    if ($null -ne $codeKey -and $hints.ContainsKey($codeKey)) {
        $message = "$message. $($hints[$codeKey])"
    }

    return $message
}
