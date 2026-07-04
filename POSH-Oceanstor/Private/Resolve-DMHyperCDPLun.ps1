function Resolve-DMHyperCDPLun {
    [CmdletBinding()]
    param(
        [pscustomobject]$WebSession,
        [string]$LunId,
        [string]$LunName,
        [psobject]$InputObject
    )

    if ($InputObject) {
        if ($InputObject.Id) {
            $LunId = $InputObject.Id
        }
        elseif ($InputObject.Name) {
            $LunName = $InputObject.Name
        }
        else {
            throw 'Piped LUN input must include an Id or Name property.'
        }
    }

    if ($LunId) {
        $lun = @(Get-DMlun -WebSession $WebSession -Id $LunId)[0]
        if ($null -eq $lun) {
            throw "Invalid LunId '$LunId'."
        }
        return $lun
    }

    if ($LunName) {
        $matches = @(Get-DMlun -WebSession $WebSession -Name $LunName | Where-Object Name -EQ $LunName)
        if ($matches.Count -eq 1) {
            return $matches[0]
        }
        if ($matches.Count -gt 1) {
            throw "LunName is ambiguous because more than one LUN is named '$LunName'."
        }
        throw "Invalid LunName '$LunName'."
    }

    throw 'LunId, LunName, or a piped LUN object is required.'
}
