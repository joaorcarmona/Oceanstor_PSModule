function get-DMLunSnapshots {
	<#
	.SYNOPSIS
		Retrieves Huawei OceanStor LUN snapshots.

	.DESCRIPTION
		Uses the OceanStor batch snapshot information interface to retrieve
		LUN snapshots and maps each record to an OceanstorLunSnapshot object.

	.PARAMETER WebSession
		Optional session for the REST call. If omitted, the deviceManager
		global variable is used.

	.PARAMETER LunName
		Optional name of the source LUN whose snapshots should be returned.
		Valid values are checked against get-DMluns and support tab completion.

	.OUTPUTS
		OceanstorLunSnapshot objects returned by the storage system.

	.EXAMPLE
		PS C:\> get-DMLunSnapshots -WebSession $session

	.EXAMPLE
		PS C:\> $snapshots = get-DMLunSnapshots

	.EXAMPLE
		PS C:\> get-DMLunSnapshots -WebSession $session -LunName 'production-db'
	#>
	[CmdletBinding()]
	param(
		[Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
		[pscustomobject]$WebSession,

		[Parameter(ValueFromPipelineByPropertyName = $true, Position = 1)]
		[Alias('SourceLunName')]
		[ValidateScript({
			if ($WebSession) {
				$session = $WebSession
			} else {
				$session = $deviceManager
			}

			$luns = get-DMluns -WebSession $session
			$matchingLuns = @($luns | Where-Object Name -EQ $_)

			if ($matchingLuns.Count -eq 1) {
				$true
			} elseif ($matchingLuns.Count -gt 1) {
				throw "LunName is ambiguous because more than one LUN is named '$_'."
			} else {
				throw "Invalid LunName. Valid values are: $($luns.Name -join ', ')"
			}
		})]
		[ArgumentCompleter({
			param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

			if ($fakeBoundParameters.ContainsKey('WebSession')) {
				$session = $fakeBoundParameters.WebSession
			} else {
				$session = $deviceManager
			}

			(get-DMluns -WebSession $session).Name |
				Sort-Object -Unique |
				Where-Object { $_ -like "$wordToComplete*" }
		})]
		[string]$LunName
	)

	if ($WebSession) {
		$session = $WebSession
	} else {
		$session = $deviceManager
	}

	$defaultDisplaySet = 'Id', 'Name', 'Source Lun Name', 'Health Status', 'Running Status'
	$displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
		'DefaultDisplayPropertySet',
		[string[]]$defaultDisplaySet
	)
	$standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

	$resource = 'snapshot'
	if ($LunName) {
		$sourceLun = @(get-DMluns -WebSession $session | Where-Object Name -EQ $LunName)[0]
		$resource = "snapshot?filter=SOURCELUNID:$($sourceLun.Id)"
	}

	$response = invoke-DeviceManager -WebSession $session -Method 'GET' -Resource $resource |
		Select-Object -ExpandProperty data
	$snapshots = [System.Collections.ArrayList]::new()

	foreach ($snapshotData in @($response)) {
		$snapshot = [OceanstorLunSnapshot]::new($snapshotData, $session)
		$snapshot | Add-Member MemberSet PSStandardMembers $standardMembers -Force
		[void]$snapshots.Add($snapshot)
	}

	return $snapshots
}
