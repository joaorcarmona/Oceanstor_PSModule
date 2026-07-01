function ConvertFrom-DMCasedHashtable {
    # Recursively converts a Hashtable (e.g. from ConvertFrom-Json -AsHashtable) to PSCustomObject,
    # deduplicating case-conflicting keys by preferring the all-uppercase variant.
    param([object]$InputObject)
    if ($InputObject -is [System.Collections.IDictionary]) {
        $seen   = @{}
        $result = [ordered]@{}
        foreach ($key in @($InputObject.Keys)) {
            $lower = $key.ToLowerInvariant()
            if ($seen.ContainsKey($lower)) {
                if ($key -ceq $key.ToUpperInvariant()) {
                    $existing = $seen[$lower]
                    $result.Remove($existing)
                    $result[$key] = ConvertFrom-DMCasedHashtable $InputObject[$key]
                    $seen[$lower] = $key
                }
            } else {
                $seen[$lower] = $key
                $result[$key] = ConvertFrom-DMCasedHashtable $InputObject[$key]
            }
        }
        return [pscustomobject]$result
    }
    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        return @($InputObject | ForEach-Object { ConvertFrom-DMCasedHashtable $_ })
    }
    return $InputObject
}

function Copy-DMTraceValue {
	param(
		[Parameter(ValueFromPipeline = $true)]
		[object]$Value
	)

	if ($null -eq $Value -or $Value -is [string] -or $Value.GetType().IsValueType) {
		return $Value
	}

	if ($Value -is [System.Collections.IDictionary]) {
		$copy = [ordered]@{}
		foreach ($key in $Value.Keys) {
			if ([string]$key -match '(?i)(password|passwd|pwd|token|secret)') {
				$copy[$key] = '[REDACTED]'
			}
			else {
				$copy[$key] = Copy-DMTraceValue -Value $Value[$key]
			}
		}
		return [pscustomobject]$copy
	}

	if ($Value -is [System.Collections.IEnumerable]) {
		return @($Value | ForEach-Object { Copy-DMTraceValue -Value $_ })
	}

	$copy = [ordered]@{}
	foreach ($property in $Value.PSObject.Properties) {
		if ($property.Name -match '(?i)(password|passwd|pwd|token|secret)') {
			$copy[$property.Name] = '[REDACTED]'
		}
		else {
			$copy[$property.Name] = Copy-DMTraceValue -Value $property.Value
		}
	}
	return [pscustomobject]$copy
}

function Write-DMRequestTrace {
	param(
		[Parameter(Mandatory)][datetime]$StartedAt,
		[Parameter(Mandatory)][string]$Method,
		[Parameter(Mandatory)][string]$Resource,
		[Parameter(Mandatory)][string]$Uri,
		[hashtable]$BodyData,
		[switch]$ApiV2,
		[object]$Response,
		[string]$Exception
	)

	$traceAction = Get-Variable -Name DeviceManagerTraceAction -Scope Script -ErrorAction SilentlyContinue
	if ($null -eq $traceAction -or $null -eq $traceAction.Value) {
		return
	}

	$contextVariable = Get-Variable -Name DeviceManagerTraceContext -Scope Script -ErrorAction SilentlyContinue
	$context = if ($null -ne $contextVariable) { $contextVariable.Value } else { $null }
	$entry = [pscustomobject]@{
		Timestamp  = $StartedAt.ToString('o')
		DurationMs = [math]::Round(((Get-Date) - $StartedAt).TotalMilliseconds, 2)
		Step       = if ($context) { $context.Name } else { $null }
		Category   = if ($context) { $context.Category } else { $null }
		Method     = $Method
		Resource   = $Resource
		ApiV2      = [bool]$ApiV2
		Uri        = $Uri
		Request    = Copy-DMTraceValue -Value $BodyData
		Response   = Copy-DMTraceValue -Value $Response
		Exception  = $Exception
	}

	try {
		& $traceAction.Value $entry
	}
	catch {
		Write-Verbose "DeviceManager trace action failed: $($_.Exception.Message)"
	}
}

function Invoke-DeviceManager{
	<#
	.SYNOPSIS
		Invokes a the Huawei Oceanstor Rest API

	.DESCRIPTION
		Function to to invoke the Huawei Oceanstor REST API, by method "GET","PUT","POST","DELETE" for any of the resources.

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used
	.PARAMETER method
		Mandatory parameter to define the REST call method to be used. Acceptable Values "GET","PUT","POST","DELETE"
	.PARAMETER resource
		Mandatory parameter to define the resource to be invoke. Any resource defines by Huawei Oceanstor REST API is acceptable

	.INPUTS

	.OUTPUTS
		returns the results of Huawei Oceanstor REST API call

	.EXAMPLE

		PS C:\> Invoke-DeviceManager -webSession $session -method "GET" -resource "lun"

		OR

		PS C:\> $hosts = Invoke-DeviceManager -method "GET" -resource "host"

	.NOTES
		Filename: Invoke-DeviceManager.ps1
		Author: Joao Carmona
		Modified date: 2022-05-22
		Version 0.2

	.LINK
	#>
    [Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,Position=0,Mandatory=$false)]
        [pscustomobject]$WebSession,
    [Parameter(Position=1,Mandatory=$true)]
        [ValidateSet("GET","POST","PUT","DELETE")]
        [string]$Method,
    [Parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,Position=2,Mandatory=$true)]
        [String]$Resource,
	[Parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,Mandatory=$false)]
		[System.Collections.Hashtable]$BodyData,
	[Parameter(Mandatory=$false)]
		[switch]$ApiV2
	)

    if ($WebSession){
        $session = $WebSession
    } else {
        $session = $deviceManager
    }

    if ($null -eq $session) {
        throw 'No OceanStor session available. Call Connect-deviceManager first, or pass a session via -WebSession.'
    }

	if ($ApiV2) {
		$RestURI = "https://$($session.hostname):8088/api/v2/$resource"
	} else {
		$RestURI = "https://$($session.hostname):8088/deviceManager/rest/$($session.DeviceId)/$resource"
	}

	$startedAt = Get-Date
	try {
		# Preserve the certificate validation choice made when the session was created.
		$invokeParams = @{
			Method      = $Method
			Uri         = $RestURI
			Headers     = $session.Headers
			WebSession  = $session.WebSession
			ContentType = 'application/json'
		}
		if ($session.SkipCertificateCheck) {
			$invokeParams.SkipCertificateCheck = $true
		}

		if ($BodyData){
			$JsonBody = ConvertTo-Json $BodyData
			$invokeParams.Body = $JsonBody
		}
		$result = Invoke-RestMethod @invokeParams

		# Some PS7 builds fall back to returning the raw JSON string instead of throwing when
		# the response body contains case-conflicting duplicate keys (e.g. 'snapType'/'SNAPTYPE'
		# on the fssnapshot endpoint). Convert to PSCustomObject using the case-aware helper so
		# callers always receive a consistent object type.
		if ($result -is [string] -and $result) {
			try {
				$result = ConvertFrom-DMCasedHashtable ($result | ConvertFrom-Json -AsHashtable)
			} catch {
				Write-Verbose "String response from '$RestURI' could not be re-parsed: $($_.Exception.Message)"
			}
		}

		Write-DMRequestTrace -StartedAt $startedAt -Method $Method -Resource $Resource -Uri $RestURI `
			-BodyData $BodyData -ApiV2:$ApiV2 -Response $result
		return $result
	}
	catch {
		$originalError = $_
		# Some OceanStor endpoints return JSON bodies with the same key in different cases
		# (e.g. "snapType" and "SNAPTYPE"). Invoke-RestMethod cannot parse these; fall back
		# to Invoke-WebRequest + ConvertFrom-Json -AsHashtable, which uses a case-sensitive
		# hashtable, then normalize to a PSCustomObject preferring the uppercase key.
		# PS7 may surface the duplicate-key parse error in different ways depending on version.
		# Check the FullyQualifiedErrorId (most stable), the exception message, and the full
		# ErrorRecord string representation as a belt-and-suspenders guard.
		$isDuplicateKeyParseError = (
			$_.FullyQualifiedErrorId -like '*CannotConvertContent*' -or
			$_.Exception.Message     -like '*keys with different casing*' -or
			"$_"                     -like '*keys with different casing*'
		)
		if ($isDuplicateKeyParseError) {
			try {
				$rawResponse = Invoke-WebRequest @invokeParams
				$result = ConvertFrom-DMCasedHashtable ($rawResponse.Content | ConvertFrom-Json -AsHashtable)
				Write-DMRequestTrace -StartedAt $startedAt -Method $Method -Resource $Resource -Uri $RestURI `
					-BodyData $BodyData -ApiV2:$ApiV2 -Response $result
				return $result
			} catch {
				Write-Verbose "Invoke-WebRequest fallback also failed for '$RestURI': $($_.Exception.Message)"
			}
		}
		Write-DMRequestTrace -StartedAt $startedAt -Method $Method -Resource $Resource -Uri $RestURI `
			-BodyData $BodyData -ApiV2:$ApiV2 -Exception $originalError.Exception.Message
		throw $originalError
	}
}
