function Remove-DMQosPolicy {
    <#
    .SYNOPSIS
        Removes a Huawei Oceanstor SmartQoS policy.

    .DESCRIPTION
        Removes a SmartQoS policy via the ioclass resource.

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .PARAMETER Name
        Name of the SmartQoS policy to remove. Mutually exclusive with Id (enforced by parameter set).

    .PARAMETER Id
        ID of the SmartQoS policy to remove. Mutually exclusive with Name (enforced by parameter set).

    .PARAMETER VstoreId
        Optional vStore ID.

    .INPUTS
        System.Management.Automation.PSCustomObject

    .OUTPUTS
        System.Object

    .EXAMPLE
        PS> Remove-DMQosPolicy -Name 'qos01'

    .EXAMPLE
        PS> Remove-DMQosPolicy -Id '1'

    .NOTES
        Filename: Remove-DMQosPolicy.ps1
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName', ValueFromPipelineByPropertyName = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
                $matchingItems = @(Get-DMQosPolicy -WebSession $session | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) { return $true }
                if ($matchingItems.Count -gt 1) { throw "Name is ambiguous because more than one SmartQoS policy is named '$_'." }
                throw 'Invalid Name.'
            })]
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
        [ValidateScript({
                $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
                $matchingItems = @(Get-DMQosPolicy -WebSession $session -Id $_)
                if ($matchingItems.Count -eq 1) { return $true }
                throw 'Invalid Id.'
            })]
        [string]$Id,

        [string]$VstoreId
    )

    process {
        try {
            $session = if ($WebSession) {
                $WebSession
            }
            else {
                $script:CurrentOceanstorSession
            }

            if ($PSCmdlet.ParameterSetName -eq 'ById') {
                $policy = @(Get-DMQosPolicy -WebSession $session -Id $Id)[0]
                if ($null -eq $policy) { throw "Could not resolve 'Id' - the object may have been removed since parameter validation." }
            }
            else {
                $policy = @(Get-DMQosPolicy -WebSession $session | Where-Object Name -EQ $Name)[0]
                if ($null -eq $policy) { throw "Could not resolve 'Name' - the object may have been removed since parameter validation." }
            }

            $resource = "ioclass/$($policy.Id)"
            if ($VstoreId) {
                $resource += "?vstoreId=$([uri]::EscapeDataString($VstoreId))"
            }

            if ($PSCmdlet.ShouldProcess($policy.Name, 'Remove SmartQoS policy')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
