function Resolve-DMHyperCDPSchedule {
    [CmdletBinding()]
    param(
        [pscustomobject]$WebSession,
        [string]$Id,
        [string]$Name,
        [psobject]$InputObject
    )

    if ($InputObject) {
        if ($InputObject.Id) {
            $Id = $InputObject.Id
        }
        elseif ($InputObject.Name) {
            $Name = $InputObject.Name
        }
        else {
            throw 'Piped schedule input must include an Id or Name property.'
        }
    }

    if ($Id) {
        $schedule = @(Get-DMHyperCDPSchedule -WebSession $WebSession -Id $Id)[0]
        if ($null -eq $schedule) {
            throw "Invalid HyperCDP schedule Id '$Id'."
        }
        return $schedule
    }

    if ($Name) {
        $matches = @(Get-DMHyperCDPSchedule -WebSession $WebSession -Name $Name | Where-Object Name -EQ $Name)
        if ($matches.Count -eq 1) {
            return $matches[0]
        }
        if ($matches.Count -gt 1) {
            throw "HyperCDP schedule name is ambiguous because more than one schedule is named '$Name'."
        }
        throw "Invalid HyperCDP schedule name '$Name'."
    }

    throw 'ScheduleId, ScheduleName, or a piped schedule object is required.'
}
