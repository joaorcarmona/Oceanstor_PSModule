function Set-DMHostInitiators {
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
            Get-DMHostInitiators -WebSession $WebSession -HostId $hostObject.id -InitatorType FibreChannel
            Get-DMHostInitiators -WebSession $WebSession -HostId $hostObject.id -InitatorType ISCSI
        )

        $hostObject
    }
}
