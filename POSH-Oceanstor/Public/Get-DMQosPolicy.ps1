function Get-DMQosPolicy {
    <#
    .SYNOPSIS
        Gets Huawei Oceanstor SmartQoS policies.

    .DESCRIPTION
        Gets SmartQoS policies via the ioclass resource. ioclass is not an ApiV2 resource,
        so filter fields use uppercase names (NAME, ID, POLICYTYPE, PARENTPOLICYID).

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .PARAMETER Name
        Optional policy name to search for, positional. When omitted, every policy is returned. Supports PowerShell wildcards (*, ?, [...]); without one, the comparison is an exact match.

    .PARAMETER Id
        Optional policy ID to search for. Mutually exclusive with Name (enforced by parameter set). Returns exactly one policy, exact match only, no wildcard support.

    .PARAMETER ParentPolicyId
        Optional parent (hierarchical) policy ID to search child policies of.

    .PARAMETER VstoreId
        Optional vstore ID to scope the unfiltered policy list to. Only applies when no Name/Id selector is supplied.

    .INPUTS
        System.Management.Automation.PSCustomObject

    .OUTPUTS
        OceanstorQosPolicy

    .EXAMPLE
        PS> Get-DMQosPolicy

    .EXAMPLE
        PS> Get-DMQosPolicy -Name 'qos01'

    .EXAMPLE
        PS> Get-DMQosPolicy -Id '1'

    .NOTES
        Filename: Get-DMQosPolicy.ps1
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    # String form: class type literals in attributes do not resolve inside module scope.
    [OutputType('OceanstorQosPolicy')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,

        [Parameter(ParameterSetName = 'ByName', Position = 0, Mandatory = $false)]
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

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter(ParameterSetName = 'ByParentPolicyId', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ParentPolicyId,

        [string]$VstoreId
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    function Get-DMQosPolicyAllInternal {
        param($session, $VstoreId)

        $resource = 'ioclass'
        if ($VstoreId) {
            $resource += "?vstoreId=$VstoreId"
        }
        $response = Invoke-DMPagedRequest -WebSession $session -Resource $resource
        $policies = New-Object System.Collections.ArrayList

        foreach ($policy in $response) {
            [void]$policies.Add([OceanstorQosPolicy]::new($policy, $session))
        }

        return @($policies)
    }

    function Get-DMQosPolicyFilteredInternal {
        param($session, $ApiField, $Keyword)

        $hasWildcard = $Keyword -match '[*?\[\]]'

        if (-not $hasWildcard) {
            $resource = "ioclass?filter=$($ApiField)::$([uri]::EscapeDataString($Keyword))"
        }
        elseif ($Keyword -match '^\*?([^*?\[\]]+)\*?$') {
            $resource = "ioclass?filter=$($ApiField):$([uri]::EscapeDataString($Matches[1]))"
        }
        else {
            $resource = 'ioclass'
        }

        $response = Invoke-DMPagedRequest -WebSession $session -Resource $resource
        $policies = New-Object System.Collections.ArrayList

        foreach ($policy in $response) {
            [void]$policies.Add([OceanstorQosPolicy]::new($policy, $session))
        }

        return @($policies)
    }

    $result = switch ($PSCmdlet.ParameterSetName) {
        'ById' { Get-DMQosPolicyFilteredInternal -session $session -ApiField 'ID' -Keyword $Id }
        'ByParentPolicyId' { Get-DMQosPolicyFilteredInternal -session $session -ApiField 'PARENTPOLICYID' -Keyword $ParentPolicyId }
        default {
            if ($Name) {
                Get-DMQosPolicyFilteredInternal -session $session -ApiField 'NAME' -Keyword $Name
            }
            else {
                Get-DMQosPolicyAllInternal -session $session -VstoreId $VstoreId
            }
        }
    }

    return @($result)
}
