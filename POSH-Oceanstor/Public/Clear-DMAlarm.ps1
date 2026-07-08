<#
.SYNOPSIS
    Clears a Huawei Oceanstor Storage alarm.

.DESCRIPTION
    Clears one or more current alarms via the OceanStor "Interface for Clearing an Alarm"
    (DELETE alarm/currentalarm?sequence=<Alarm SN>).

    Alarms are identified by their sequence number (the "Alarm SN" property exposed by
    Get-DMAlarm). The cmdlet is pipeline-aware: pipe the objects returned by Get-DMAlarm
    straight into it and each alarm is cleared independently. A failure on one alarm (for
    example a REST error, or an already-cleared SN) is reported as a non-terminating error
    and does not stop the remaining alarms from being processed.

    Because clearing an alarm is a destructive, non-reversible action, the cmdlet supports
    -WhatIf and prompts for -Confirm by default (ConfirmImpact = High), like the Remove-DM*
    commands.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's
    cached $script:CurrentOceanstorSession session is used. When alarms are piped from
    Get-DMAlarm the originating session flows through automatically.

.PARAMETER Sequence
    Sequence number (Alarm SN) of the alarm to clear. Bound automatically from the "Alarm SN"
    property when Get-DMAlarm objects are piped in.

.INPUTS
    OceanStorAlarm

    You can pipe alarm objects returned by Get-DMAlarm.

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object for each cleared alarm.

.EXAMPLE
    PS> Get-DMAlarm | Clear-DMAlarm

    Prompts for confirmation and clears every currently returned alarm.

.EXAMPLE
    PS> Get-DMAlarm -AlarmStatus Unrecovered -Last (New-TimeSpan -Hours 24) | Clear-DMAlarm -Confirm:$false

    Clears all unrecovered alarms raised in the last 24 hours without prompting.

.EXAMPLE
    PS> Clear-DMAlarm -Sequence 3482 -WhatIf

    Shows what would happen if alarm SN 3482 were cleared.

.NOTES
    Filename: Clear-DMAlarm.ps1
#>
function Clear-DMAlarm {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Alias('Alarm SN', 'SN', 'AlarmSN')]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^\d+$')]
        [string]$Sequence
    )

    begin {
        # Session used when no per-item WebSession flows in from the pipeline.
        $defaultSession = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    }

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $defaultSession }

            if ($PSCmdlet.ShouldProcess("Alarm SN $Sequence", 'Clear alarm')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource "alarm/currentalarm?sequence=$Sequence"
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
