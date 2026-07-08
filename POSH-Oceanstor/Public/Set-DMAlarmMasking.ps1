<#
.SYNOPSIS
    Enables or disables masking for a Huawei OceanStor alarm.

.DESCRIPTION
    Modifies the masking state of a single alarm definition via the OceanStor
    "Interface for Modifying Alarm Masking" (PUT ALARM_DEFINITION, OceanStor Dorado
    6.1.6 REST Interface Reference section 4.2.2.3.1).

    Masking suppresses an alarm on the array. Use -Enable to turn masking on
    (enableClose = true) or -Disable to turn it off (enableClose = false); the two
    switches are mutually exclusive and one is required. The alarm to modify is
    identified by its alarm ID (the "Alarm Id" property exposed by
    Get-DMAlarmMasking), so masking records can be piped straight in.

    Changing alarm masking is a monitoring-configuration change (reversible, not
    destructive). The cmdlet supports -WhatIf and honours -Confirm
    (ConfirmImpact = Medium).

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the
    module's cached $script:CurrentOceanstorSession session is used. When masking
    records are piped from Get-DMAlarmMasking the originating session flows through
    automatically.

.PARAMETER AlarmId
    Alarm ID whose masking state is to be changed. Bound automatically from the
    "Alarm Id" property when Get-DMAlarmMasking objects are piped in.

.PARAMETER Enable
    Enables masking for the alarm (enableClose = true). Mutually exclusive with
    -Disable.

.PARAMETER Disable
    Disables masking for the alarm (enableClose = false). Mutually exclusive with
    -Enable.

.INPUTS
    OceanStorAlarmMasking

    You can pipe masking records returned by Get-DMAlarmMasking.

.OUTPUTS
    System.Management.Automation.PSCustomObject

    Returns the OceanStor API error object for the modified alarm.

.EXAMPLE
    PS> Set-DMAlarmMasking -AlarmId 64425164820 -Enable

    Enables masking for alarm ID 64425164820.

.EXAMPLE
    PS> Set-DMAlarmMasking -AlarmId 64425164820 -Disable

    Disables masking for alarm ID 64425164820.

.EXAMPLE
    PS> Get-DMAlarmMasking -Level Info | Set-DMAlarmMasking -Enable -Confirm:$false

    Masks every informational alarm without prompting.

.EXAMPLE
    PS> Set-DMAlarmMasking -AlarmId 64425164820 -Enable -WhatIf

    Shows what would happen without changing the masking state.

.NOTES
    Filename: Set-DMAlarmMasking.ps1
#>
function Set-DMAlarmMasking {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'Enable')]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Alias('CMO_ALARM_ID', 'Alarm Id')]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^\d+$')]
        [string]$AlarmId,

        [Parameter(Mandatory = $true, ParameterSetName = 'Enable')]
        [switch]$Enable,

        [Parameter(Mandatory = $true, ParameterSetName = 'Disable')]
        [switch]$Disable
    )

    begin {
        # Session used when no per-item WebSession flows in from the pipeline.
        $defaultSession = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    }

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $defaultSession }

            $enableClose = ($PSCmdlet.ParameterSetName -eq 'Enable')
            $action = if ($enableClose) { 'Enable alarm masking' } else { 'Disable alarm masking' }

            if ($PSCmdlet.ShouldProcess("Alarm ID $AlarmId", $action)) {
                $body = @{
                    CMO_ALARM_ID = $AlarmId
                    enableClose  = $enableClose
                }
                $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'ALARM_DEFINITION' -BodyData $body
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
