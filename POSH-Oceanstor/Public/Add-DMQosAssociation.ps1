function Add-DMQosAssociation {
    <#
    .SYNOPSIS
        Associates a Huawei Oceanstor SmartQoS policy with a LUN group, host, vStore, or child policy.

    .DESCRIPTION
        Adds an association via the ioclass/create_associate resource. Exactly one target
        parameter must be supplied. Individual LUN/file system attachment is not handled by
        this cmdlet - use New-DMQosPolicy/Set-DMQosPolicy's LunName/LunId/FileSystemName/FileSystemId
        parameters instead. ASSOCIATEOBJTYPE values used: 230 (child SmartQoS policy),
        256 (LUN group), 21 (host), 16442 (vStore).

        A SmartQoS policy can only be bound to one object type. The cmdlet pre-validates the
        resolved policy's current binding (LUN, file system, host, or child policy) and fails
        with a clear message - without calling the array - when the requested association
        would conflict with an existing binding of a different type.

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .PARAMETER Name
        Name of the SmartQoS (parent) policy. Mutually exclusive with Id (enforced by parameter set).

    .PARAMETER Id
        ID of the SmartQoS (parent) policy. Mutually exclusive with Name (enforced by parameter set).

    .PARAMETER LunGroupName
        Name of the LUN group to associate. Mutually exclusive with the other target parameters.

    .PARAMETER LunGroupId
        ID of the LUN group to associate. Mutually exclusive with the other target parameters.

    .PARAMETER HostName
        Name of the host to associate. Mutually exclusive with the other target parameters.

    .PARAMETER HostId
        ID of the host to associate. Mutually exclusive with the other target parameters.

    .PARAMETER VstoreName
        Name of the vStore to associate. Mutually exclusive with the other target parameters.

    .PARAMETER VstoreAssociationId
        ID of the vStore to associate. Mutually exclusive with the other target parameters.

    .PARAMETER ChildPolicyName
        Name of the child SmartQoS policy to associate (hierarchical policy). Mutually exclusive with the other target parameters.

    .PARAMETER ChildPolicyId
        ID of the child SmartQoS policy to associate (hierarchical policy). Mutually exclusive with the other target parameters.

    .INPUTS
        System.Management.Automation.PSCustomObject

    .OUTPUTS
        System.Object

    .EXAMPLE
        PS> Add-DMQosAssociation -Name 'qos01' -LunGroupName 'production-luns'

    .EXAMPLE
        PS> Add-DMQosAssociation -Id '1' -HostName 'esx01'

    .EXAMPLE
        PS> Add-DMQosAssociation -Name 'qos01-parent' -ChildPolicyName 'qos01-child'

    .NOTES
        Filename: Add-DMQosAssociation.ps1
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

        [string]$LunGroupName,
        [string]$LunGroupId,
        [string]$HostName,
        [string]$HostId,
        [string]$VstoreName,
        [string]$VstoreAssociationId,
        [string]$ChildPolicyName,
        [string]$ChildPolicyId
    )

    begin {
        $targetParams = 'LunGroupName', 'LunGroupId', 'HostName', 'HostId', 'VstoreName', 'VstoreAssociationId', 'ChildPolicyName', 'ChildPolicyId'
        $specified = @($targetParams | Where-Object { $PSBoundParameters.ContainsKey($_) })
        if ($specified.Count -ne 1) {
            throw "Specify exactly one of: $($targetParams -join ', ')."
        }
    }

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

            $policy = switch ($PSCmdlet.ParameterSetName) {
                'ById' { @(Get-DMQosPolicy -WebSession $session -Id $Id)[0] }
                default { @(Get-DMQosPolicy -WebSession $session -Name $Name | Where-Object Name -EQ $Name)[0] }
            }
            if ($null -eq $policy) { throw 'Could not resolve the SmartQoS policy.' }

            if ($LunGroupName) {
                $group = @(Get-DMlunGroup -WebSession $session -Name $LunGroupName | Where-Object Name -EQ $LunGroupName)[0]
                if ($null -eq $group) { throw "Could not resolve LunGroupName '$LunGroupName'." }
                $associateObjType = 256
                $associateObjId = $group.Id
                $targetDescription = "LUN group '$LunGroupName'"
            }
            elseif ($LunGroupId) {
                $associateObjType = 256
                $associateObjId = $LunGroupId
                $targetDescription = "LUN group '$LunGroupId'"
            }
            elseif ($HostName) {
                $targetHost = @(Get-DMhost -WebSession $session -Name $HostName | Where-Object Name -EQ $HostName)[0]
                if ($null -eq $targetHost) { throw "Could not resolve HostName '$HostName'." }
                $associateObjType = 21
                $associateObjId = $targetHost.Id
                $targetDescription = "host '$HostName'"
            }
            elseif ($HostId) {
                $associateObjType = 21
                $associateObjId = $HostId
                $targetDescription = "host '$HostId'"
            }
            elseif ($VstoreName) {
                $vstore = @(Get-DMvStore -WebSession $session | Where-Object Name -EQ $VstoreName)[0]
                if ($null -eq $vstore) { throw "Could not resolve VstoreName '$VstoreName'." }
                $associateObjType = 16442
                $associateObjId = $vstore.Id
                $targetDescription = "vStore '$VstoreName'"
            }
            elseif ($VstoreAssociationId) {
                $associateObjType = 16442
                $associateObjId = $VstoreAssociationId
                $targetDescription = "vStore '$VstoreAssociationId'"
            }
            elseif ($ChildPolicyName) {
                $childPolicy = @(Get-DMQosPolicy -WebSession $session -Name $ChildPolicyName | Where-Object Name -EQ $ChildPolicyName)[0]
                if ($null -eq $childPolicy) { throw "Could not resolve ChildPolicyName '$ChildPolicyName'." }
                $associateObjType = 230
                $associateObjId = $childPolicy.Id
                $targetDescription = "child policy '$ChildPolicyName'"
            }
            else {
                $associateObjType = 230
                $associateObjId = $ChildPolicyId
                $targetDescription = "child policy '$ChildPolicyId'"
            }

            # Pre-validation: a SmartQoS (ioclass) policy binds to a single object type.
            # Associating an object whose type differs from the one already bound triggers
            # the array's ioclass object-type conflict (e.g. a policy already bound to a LUN
            # cannot also take a LUN group). Detect the current binding from the resolved
            # policy and fail with a clear message instead of firing a request the array
            # will reject. Empty entries are filtered so an absent list ('@($null)') does
            # not read as a binding.
            $boundTo = [ordered]@{
                'LUN'          = @($policy.'Lun List'    | Where-Object { $_ })
                'file system'  = @($policy.'FS List'     | Where-Object { $_ })
                'host'         = @($policy.'Host List'   | Where-Object { $_ })
                'child policy' = @($policy.'Policy List' | Where-Object { $_ })
            }
            # Adding an object of the same type as an existing binding is legitimate (a
            # second host, or another child policy on a hierarchical parent), so exclude the
            # compatible bucket from the conflict check. LUN group (256) and vStore (16442)
            # have no same-type list exposed on the policy object, so any existing binding
            # conflicts with them.
            $compatibleBinding = switch ($associateObjType) {
                21 { 'host' }
                230 { 'child policy' }
                default { $null }
            }
            $conflicts = foreach ($kind in $boundTo.Keys) {
                if ($kind -ne $compatibleBinding -and $boundTo[$kind].Count -gt 0) {
                    "$kind ($($boundTo[$kind] -join ', '))"
                }
            }
            if ($conflicts) {
                throw "SmartQoS policy '$($policy.Name)' is already associated with $($conflicts -join '; '). A SmartQoS policy can only be bound to one object type; remove the existing association before adding $targetDescription."
            }

            $body = @{
                ID                   = $policy.Id
                ASSOCIATEOBJTYPE     = $associateObjType
                ASSOCIATEOBJIDLIST   = @($associateObjId)
            }

            if ($PSCmdlet.ShouldProcess($policy.Name, "Associate $targetDescription")) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'ioclass/create_associate' -BodyData $body
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
