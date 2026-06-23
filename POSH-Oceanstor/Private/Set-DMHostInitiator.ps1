function Set-DMHostInitiator {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [object[]]$InputObject,
        [Parameter(Mandatory=$true)]
        [pscustomobject]$WebSession
    )

    foreach ($hostObject in $InputObject) {
        $hostObject.initiators = @(
            Get-DMHostInitiator -WebSession $WebSession -HostId $hostObject.id -InitiatorType FibreChannel
            Get-DMHostInitiator -WebSession $WebSession -HostId $hostObject.id -InitiatorType ISCSI
        )

        $hostObject
    }
}
