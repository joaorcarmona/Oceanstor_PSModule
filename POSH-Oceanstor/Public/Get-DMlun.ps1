function Get-DMlun {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage Luns

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage Luns. With no arguments, returns every
		LUN. With Keyword supplied (positionally or named), looks the LUN up by Name first;
		if that finds nothing, falls back to WWN. Keyword supports PowerShell wildcards
		(*, ?, [...]); without one, both lookups are exact matches. This lets a single value
		be passed with no parameter name at all, e.g. Get-DMlun 'finance*' or
		Get-DMlun '658be72100f6793b6bb9512e000000e1'.

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

	.PARAMETER Keyword
		Optional LUN Name or WWN to search for, positional. When omitted, every LUN is returned. Name is tried first, WWN is a fallback when Name finds nothing. Supports PowerShell wildcards (*, ?, [...]); without one, the comparison is an exact match. Also available as -Name.

	.PARAMETER Id
		Optional LUN ID to search for. Mutually exclusive with Keyword/Name (enforced by parameter set). Returns exactly one LUN, exact match only, no wildcard support.

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession by property name.

	.OUTPUTS
		OceanstorLunv3
		OceanstorLunv6

		Returns LUN objects. The class depends on the connected OceanStor version.

	.EXAMPLE

		PS C:\> Get-DMlun -webSession $session

		OR

		PS C:\> $luns = Get-DMlun

		OR

		PS C:\> Get-DMlun 'finance*'

		OR

		PS C:\> Get-DMlun '658be72100f6793b6bb9512e000000e1'

		OR

		PS C:\> Get-DMlun -Id '1'

	.NOTES
		Filename: Get-DMlun.ps1

	.LINK
	#>
    [Cmdletbinding(DefaultParameterSetName = 'ByName')]
    [OutputType([System.Collections.ArrayList])]
    [OutputType([System.Object[]])]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,

        [Parameter(ParameterSetName = 'ByName', Position = 0, Mandatory = $false)]
        [Alias('Name')]
        [string]$Keyword,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    if ($PSCmdlet.ParameterSetName -eq 'ById') {
        return @(Get-DMLunbyFilter -WebSession $session -Filter 'Id' -Keyword $Id)
    }

    if ($Keyword) {
        $result = @(Get-DMLunbyFilter -WebSession $session -Filter 'Name' -Keyword $Keyword)
        if ($result.Count -eq 0) {
            $result = @(Get-DMLunbyFilter -WebSession $session -Filter 'WWN' -Keyword $Keyword)
        }
        return $result
    }

    $defaultDisplaySet = "Id", "Name", "Health Status", "Lun Size", "WWN"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)


    $response = Invoke-DMPagedRequest -WebSession $session -Resource 'lun'
    $StorageLuns = New-Object System.Collections.ArrayList

    $StorageVersion = $session.version.Substring(0, 2)

    if ($storageVersion -eq "V6") {
        $LunObjectClass = "OceanstorLunv6"
    }
    else {
        $LunObjectClass = "OceanstorLunv3"
    }

    foreach ($tlun in $response) {
        $lun = New-Object -TypeName $LunObjectClass -ArgumentList @($tlun, $session)
        [void]$StorageLuns.Add($lun)
    }

    $StorageLuns | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $storageLuns

    return $result
}

Set-Alias -Name Get-DMluns -Value Get-DMlun
