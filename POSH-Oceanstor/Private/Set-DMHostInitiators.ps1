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
            get-DMHostInitiators -WebSession $WebSession -HostId $hostObject.id -InitatorType FibreChannel
            get-DMHostInitiators -WebSession $WebSession -HostId $hostObject.id -InitatorType ISCSI
        )

        $hostObject
    }
}
