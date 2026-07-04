function Disable-DMQosPolicy {
    <#
    .SYNOPSIS
        Deactivates a Huawei Oceanstor SmartQoS policy.

    .DESCRIPTION
        Deactivates a SmartQoS policy via the ioclass/active resource.

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .PARAMETER Name
        Name of the SmartQoS policy to deactivate. Mutually exclusive with Id (enforced by parameter set).

    .PARAMETER Id
        ID of the SmartQoS policy to deactivate. Mutually exclusive with Name (enforced by parameter set).

    .PARAMETER VstoreId
        Optional vStore ID.

    .INPUTS
        System.Management.Automation.PSCustomObject

    .OUTPUTS
        System.Object

    .EXAMPLE
        PS> Disable-DMQosPolicy -Name 'qos01'

    .EXAMPLE
        PS> Disable-DMQosPolicy -Id '1'

    .NOTES
        Filename: Disable-DMQosPolicy.ps1
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

            $body = @{
                ID            = $policy.Id
                ENABLESTATUS  = $false
            }
            if ($VstoreId) { $body.vstoreId = $VstoreId }

            if ($PSCmdlet.ShouldProcess($policy.Name, 'Deactivate SmartQoS policy')) {
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
