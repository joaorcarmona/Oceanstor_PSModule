function Start-DMQosPolicy {
    <#
    .SYNOPSIS
        Starts (activates the running state of) a Huawei Oceanstor SmartQoS policy.

    .DESCRIPTION
        Starts a SmartQoS policy via the ioclass/active resource.

        Starting a policy drives its Running Status to an active state: 'Idle' when the
        policy is outside its scheduled window or has no associated objects, or 'Running'
        when it is in-window and enforcing on associated objects. It does NOT change the
        Enabled (ENABLESTATUS) field, which stays as configured - the ioclass/active
        endpoint controls Running Status only.

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .PARAMETER Name
        Name of the SmartQoS policy to start. Mutually exclusive with Id (enforced by parameter set).

    .PARAMETER Id
        ID of the SmartQoS policy to start. Mutually exclusive with Name (enforced by parameter set).

    .PARAMETER VstoreId
        Optional vStore ID.

    .INPUTS
        System.Management.Automation.PSCustomObject

    .OUTPUTS
        System.Object

    .EXAMPLE
        PS> Start-DMQosPolicy -Name 'qos01'

    .EXAMPLE
        PS> Start-DMQosPolicy -Id '1'

    .NOTES
        Filename: Start-DMQosPolicy.ps1
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName', ValueFromPipelineByPropertyName = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMQosPolicy -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'ById', ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [string]$VstoreId
    )

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

            $policy = switch ($PSCmdlet.ParameterSetName) {
                'ById' { @(Get-DMQosPolicy -WebSession $session -Id $Id)[0] }
                default { @(Get-DMQosPolicy -WebSession $session -Name $Name | Where-Object Name -EQ $Name)[0] }
            }
            if ($null -eq $policy) { throw "Could not resolve the SmartQoS policy." }

            # ENABLESTATUS is the field name the ioclass/active endpoint expects; on this
            # resource it drives Running Status (start), not the policy's Enabled field.
            $body = @{
                ID           = $policy.Id
                ENABLESTATUS = $true
            }
            if ($VstoreId) { $body.vstoreId = $VstoreId }

            if ($PSCmdlet.ShouldProcess($policy.Name, 'Start SmartQoS policy')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'ioclass/active' -BodyData $body
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}

Set-Alias -Name Enable-DMQosPolicy -Value Start-DMQosPolicy
