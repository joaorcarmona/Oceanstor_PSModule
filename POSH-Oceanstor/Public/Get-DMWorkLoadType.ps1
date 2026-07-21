function Get-DMWorkLoadType {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage workload Type configured (only works for v6)

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage workload Types configured (only works for
		V6 arrays). With no arguments, returns every workload type. Selection is done with one of
		several mutually exclusive parameter sets:

		- Name (positional, default): filters server-side by NAME. An exact match when Name has
		  no wildcard, a fuzzy substring hint when Name has a leading and/or trailing * (a single
		  colon in filter=field:value requests a fuzzy match, a double colon an exact match). Any
		  other wildcard shape falls back to fetching every workload and filtering client-side.
		  The exact requested pattern is always re-verified client-side (-Like).
		- Id: exact match by ID, selected client-side (workload_type documents NAME as its only
		  server-side filter field, so every workload is fetched and matched on ID locally).
		- Filter/Value: match an arbitrary workload property (by regex) against a keyword.
		- CompressionEnabled / DedupeEnabled: convenience switches for the two boolean
		  properties; both use unconfirmed server-side hints and re-verify client-side.

		Name, Id, and Filter support tab completion of the connected array's workloads.

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

	.PARAMETER Name
		Optional workload type name to search for, positional. If omitted, every workload type is returned. Supports PowerShell wildcards (*, ?, [...]); without one, the comparison is an exact match. Tab completion offers existing workload type names.

	.PARAMETER Id
		Optional workload type ID to search for. Returns exactly one workload, exact match only, no wildcard support. Tab completion offers existing workload type IDs.

	.PARAMETER Filter
		Optional workload property name to filter against, used together with -Value. Tab completion offers the workload object's property names.

	.PARAMETER Value
		Value (regex) to match against the property named by -Filter. Mandatory when -Filter is supplied. Also accepts the alias -Keyword.

	.PARAMETER CompressionEnabled
		Convenience switch targeting the Compression Enabled property. Attempts a server-side
		filter=ENABLECOMPRESS:: hint (NOT confirmed as a supported workload_type filter field)
		and always re-verifies the match client-side.

	.PARAMETER DedupeEnabled
		Convenience switch targeting the Deduplication Enabled property. Attempts a server-side
		filter=ENABLEDEDUP:: hint (NOT confirmed as a supported workload_type filter field) and
		always re-verifies the match client-side.

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession.

	.OUTPUTS
		OceanStorWorkload

		Returns workload type objects. This command only works for V6 arrays.

	.EXAMPLE

		PS C:\> Get-DMWorkLoadType -webSession $session

		OR

		PS C:\> $workloads = Get-DMWorkLoadType

	.EXAMPLE

		PS C:\> Get-DMWorkLoadType 'db*'

		OR

		PS C:\> Get-DMWorkLoadType -Id '0'

	.EXAMPLE

		PS C:\> Get-DMWorkLoadType -Filter 'Compression Enabled' -Value enabled

		OR

		PS C:\> Get-DMWorkLoadType -CompressionEnabled $true

	.NOTES
		Filename: Get-DMWorkLoadType.ps1

	.LINK
	#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [Cmdletbinding(DefaultParameterSetName = 'ByName')]
    [OutputType([System.Collections.ArrayList])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,

        [Parameter(ParameterSetName = 'ByName', Position = 0, Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [Alias('WorkloadTypeName')]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMWorkLoadType -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$Name,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('WorkloadTypeId')]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMWorkLoadType -WebSession $session).Id | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$Id,

        [Parameter(ParameterSetName = 'ByFilter', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMWorkLoadType -WebSession $session | Select-Object -First 1).PSObject.Properties.Name |
                    Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$Filter,

        [Parameter(ParameterSetName = 'ByFilter', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('Keyword')]
        [string]$Value,

        [Parameter(ParameterSetName = 'ByCompressionEnabled', Mandatory = $true)]
        [bool]$CompressionEnabled,

        [Parameter(ParameterSetName = 'ByDedupeEnabled', Mandatory = $true)]
        [bool]$DedupeEnabled
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $defaultDisplaySet = "Id", "Name", "Workload Type", "Block Size", "Compression Enabled"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $resource = "workload_type?isDetailInfo=true"

    switch ($PSCmdlet.ParameterSetName) {
        'ByName' {
            if ($Name) {
                $hasWildcard = $Name -match '[*?\[\]]'
                if (-not $hasWildcard) {
                    # No wildcard: request an exact match server-side (double colon).
                    $resource += "&filter=NAME::$([uri]::EscapeDataString($Name))"
                }
                elseif ($Name -match '^\*?([^*?\[\]]+)\*?$') {
                    # Leading/trailing * only: send the literal middle as a fuzzy hint.
                    $resource += "&filter=NAME:$([uri]::EscapeDataString($Matches[1]))"
                }
                # Any other wildcard shape: no server filter, client-side -Like narrows below.
            }
        }
        'ById' {
            # Per the REST reference, workload_type supports NAME as its only filter field
            # (there is a dedicated GET /workload_type/{id}, but it errors on a missing id).
            # To keep the same "empty on not-found" behaviour as the other selectors, no
            # server-side filter is sent for Id: every workload is fetched and the exact Id is
            # matched client-side below.
        }
        'ByCompressionEnabled' {
            $apiValue = if ($CompressionEnabled) { 'true' } else { 'false' }
            # ENABLECOMPRESS backs "Compression Enabled"; UNCONFIRMED server hint, re-verified below.
            $resource += "&filter=ENABLECOMPRESS::$apiValue"
        }
        'ByDedupeEnabled' {
            $apiValue = if ($DedupeEnabled) { 'true' } else { 'false' }
            # ENABLEDEDUP backs "Deduplication Enabled"; UNCONFIRMED server hint, re-verified below.
            $resource += "&filter=ENABLEDEDUP::$apiValue"
        }
        # ByFilter: an arbitrary property has no reliable single server-side field, so every
        # workload is fetched and filtered client-side below.
    }

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource $resource | Select-DMResponseData
    $workloads = New-Object System.Collections.ArrayList

    foreach ($tworkload in $response) {
        $workload = [OceanStorWorkload]::new($tworkload, $session)
        [void]$workloads.Add($workload)
    }

    $result = switch ($PSCmdlet.ParameterSetName) {
        'ById' {
            $workloads | Where-Object Id -EQ $Id
        }
        'ByFilter' {
            $workloads | Where-Object $Filter -Match $Value
        }
        'ByCompressionEnabled' {
            $expected = if ($CompressionEnabled) { 'enabled' } else { 'disabled' }
            $workloads | Where-Object 'Compression Enabled' -EQ $expected
        }
        'ByDedupeEnabled' {
            $expected = if ($DedupeEnabled) { 'enabled' } else { 'disabled' }
            $workloads | Where-Object 'Deduplication Enabled' -EQ $expected
        }
        default {
            # ByName: -Like enforces the full wildcard pattern when Name has one and behaves
            # as an exact match when it doesn't; no Name returns every workload type.
            if ($Name) {
                $workloads | Where-Object Name -Like $Name
            }
            else {
                $workloads
            }
        }
    }

    $result | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    return $result
}

Set-Alias -Name Get-DMWorkLoadTypes -Value Get-DMWorkLoadType
