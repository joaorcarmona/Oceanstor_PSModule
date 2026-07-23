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
			if ([string]$key -match '(?i)(password|passwd|pwd|token|secret|community)') {
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
		if ($property.Name -match '(?i)(password|passwd|pwd|token|secret|community)') {
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
		[object]$BodyData,
		[switch]$ApiV2,
		[object]$Response,
		[string]$Exception,
		[object]$Session,
		[object]$StatusCode,
		[string]$RawJsonBody,
		[object]$Headers
	)

	$traceAction = Get-Variable -Name DeviceManagerTraceAction -Scope Script -ErrorAction SilentlyContinue
	if ($null -eq $traceAction -or $null -eq $traceAction.Value) {
		return
	}

	$contextVariable = Get-Variable -Name DeviceManagerTraceContext -Scope Script -ErrorAction SilentlyContinue
	$context = if ($null -ne $contextVariable) { $contextVariable.Value } else { $null }

	$depthVariable = Get-Variable -Name DeviceManagerTraceDepth -Scope Script -ErrorAction SilentlyContinue
	$depth = if ($null -ne $depthVariable -and $depthVariable.Value) { [int]$depthVariable.Value } else { 1 }

	# Read Hostname/Version defensively: a partial or legacy session object may lack them,
	# and direct member access throws under Set-StrictMode.
	$sessionHostname = $null
	$sessionVersion = $null
	if ($Session) {
		$hostProp = $Session.PSObject.Properties['Hostname']
		if ($hostProp) { $sessionHostname = $hostProp.Value }
		$versionProp = $Session.PSObject.Properties['Version']
		if ($versionProp) { $sessionVersion = $versionProp.Value }
	}

	$entry = [pscustomobject]@{
		Timestamp  = $StartedAt.ToString('o')
		DurationMs = [math]::Round(((Get-Date) - $StartedAt).TotalMilliseconds, 2)
		Step       = if ($context) { $context.Name } else { $null }
		Category   = if ($context) { $context.Category } else { $null }
		Vendor     = 'Huawei OceanStor'
		Hostname   = $sessionHostname
		Version    = $sessionVersion
		Method     = $Method
		Resource   = $Resource
		ApiV2      = [bool]$ApiV2
		Uri        = $Uri
		StatusCode = $StatusCode
		Request    = Copy-DMTraceValue -Value $BodyData
		Response   = Copy-DMTraceValue -Value $Response
		Exception  = $Exception
	}

	# Depth 2 captures the exact wire representation: the JSON string actually sent, the
	# request headers (iBaseToken redacted via Copy-DMTraceValue), and the response
	# re-serialized to JSON. Only added when explicitly requested to keep depth-1 entries lean.
	if ($depth -ge 2) {
		$rawResponse = $null
		if ($null -ne $Response) {
			try { $rawResponse = $Response | ConvertTo-Json -Depth 12 } catch { $rawResponse = "$Response" }
		}
		Add-Member -InputObject $entry -MemberType NoteProperty -Name RawJsonBody -Value $RawJsonBody
		Add-Member -InputObject $entry -MemberType NoteProperty -Name RawResponse -Value $rawResponse
		Add-Member -InputObject $entry -MemberType NoteProperty -Name Headers -Value (Copy-DMTraceValue -Value $Headers)
	}

	try {
		& $traceAction.Value $entry
	}
	catch {
		Write-Verbose "DeviceManager trace action failed: $($_.Exception.Message)"
	}
}

function Format-DMTraceConsole {
	<#
	.SYNOPSIS
		Renders a single DeviceManager trace entry as a colored console block.
	.DESCRIPTION
		Called by the trace action installed by Enable-DMRequestTrace when console output is
		enabled. Kept inside Invoke-DeviceManager.ps1 (rather than a standalone Private/*.ps1)
		so it is always dot-sourced alongside the tracer without needing an entry in the
		integrity harness's private-helper whitelist.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Deliberate colored live-debug console output; suppression is controlled by Enable-DMRequestTrace -Quiet.')]
	param(
		[Parameter(Mandatory)][object]$Entry
	)

	$depthVariable = Get-Variable -Name DeviceManagerTraceDepth -Scope Script -ErrorAction SilentlyContinue
	$depth = if ($null -ne $depthVariable -and $depthVariable.Value) { [int]$depthVariable.Value } else { 1 }

	$header = "[$($Entry.Vendor)"
	if ($Entry.Hostname) { $header += " | $($Entry.Hostname)" }
	if ($Entry.Version)  { $header += " | v$($Entry.Version)" }
	$header += ']'
	if ($Entry.Step) { $header += " ($($Entry.Step))" }
	Write-Host $header -ForegroundColor Cyan

	# --- Request ---
	Write-Host "  -> $($Entry.Method) $($Entry.Uri)" -ForegroundColor Yellow
	if ($depth -ge 2 -and $Entry.PSObject.Properties['RawJsonBody'] -and $Entry.RawJsonBody) {
		Write-Host "     body: $($Entry.RawJsonBody)" -ForegroundColor DarkYellow
	}
	elseif ($null -ne $Entry.Request) {
		$reqJson = try { $Entry.Request | ConvertTo-Json -Depth 10 -Compress } catch { "$($Entry.Request)" }
		Write-Host "     body: $reqJson" -ForegroundColor DarkYellow
	}
	if ($depth -ge 2 -and $Entry.PSObject.Properties['Headers'] -and $Entry.Headers) {
		$hdrJson = try { $Entry.Headers | ConvertTo-Json -Depth 6 -Compress } catch { "$($Entry.Headers)" }
		Write-Host "     headers: $hdrJson" -ForegroundColor DarkGray
	}

	# --- Response ---
	if ($Entry.Exception) {
		Write-Host "  <- HTTP $($Entry.StatusCode)  FAILED  ($($Entry.DurationMs) ms)" -ForegroundColor Red
		Write-Host "     $($Entry.Exception)" -ForegroundColor Red
		return
	}

	# Extract the OceanStor business result defensively -- error, code and description are all
	# optional on a given response, and direct access to a missing member throws under StrictMode.
	$businessCode = $null
	$businessDesc = $null
	if ($null -ne $Entry.Response) {
		$errorProp = $Entry.Response.PSObject.Properties['error']
		if ($errorProp -and $null -ne $errorProp.Value) {
			$codeProp = $errorProp.Value.PSObject.Properties['code']
			if ($codeProp) { $businessCode = $codeProp.Value }
			$descProp = $errorProp.Value.PSObject.Properties['description']
			if ($descProp) { $businessDesc = $descProp.Value }
		}
	}
	$respHeader = "  <- HTTP $($Entry.StatusCode)"
	if ($null -ne $businessCode) { $respHeader += "  error.code=$businessCode" }
	$respHeader += "  ($($Entry.DurationMs) ms)"
	$respColor = if ($null -ne $businessCode -and $businessCode -ne 0) { 'Red' } else { 'Green' }
	Write-Host $respHeader -ForegroundColor $respColor
	# OceanStor returns description "0" (or empty) on success -- only surface a real message.
	if ($businessDesc -and "$businessDesc" -ne '0') { Write-Host "     $businessDesc" -ForegroundColor $respColor }

	if ($depth -ge 2 -and $Entry.PSObject.Properties['RawResponse'] -and $Entry.RawResponse) {
		Write-Host "     response: $($Entry.RawResponse)" -ForegroundColor DarkGray
	}
	elseif ($null -ne $Entry.Response) {
		$respJson = try { $Entry.Response | ConvertTo-Json -Depth 10 -Compress } catch { "$($Entry.Response)" }
		Write-Host "     response: $respJson" -ForegroundColor DarkGray
	}
}

function Invoke-DeviceManager{
	<#
	.SYNOPSIS
		Invokes a the Huawei Oceanstor Rest API

	.DESCRIPTION
		Function to to invoke the Huawei Oceanstor REST API, by method "GET","PUT","POST","DELETE" for any of the resources.

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the module-scoped $script:CurrentOceanstorSession variable will be used
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
		[object]$BodyData,
	[Parameter(Mandatory=$false)]
		[ValidateRange(1, 3600)]
		[int]$TimeoutSec,
	[Parameter(Mandatory=$false)]
		[switch]$ApiV2
	)

    # --- ReadOnly access-mode guardrail (runtime enforcement) --------------------------------------
    # This is the single REST choke point every session-based array call flows through, so the
    # transversal ReadOnly brake is enforced here once instead of in ~150 cmdlets. The policy is
    # defined against the ORIGINATING public cmdlet's verb, so resolve it from the call stack: the
    # outermost POSH-Oceanstor frame is the command the user actually invoked (a Get-* that queries
    # via POST is still a read; a New/Set/Remove is a write regardless of HTTP method). Assert-
    # DMWriteAllowed reads the LIVE config, so a ReadOnly switch takes effect without a re-import.
    # Fail open when the helper is not in scope (an isolated dot-source in tests) -- the REST path
    # must never break because of the guardrail.
    if (Get-Command -Name Assert-DMWriteAllowed -ErrorAction SilentlyContinue) {
        $dmPlumbing = @('Invoke-DeviceManager', 'Assert-DMWriteAllowed', 'Invoke-DMPagedRequest', 'Save-DMDeviceManagerFile')
        $entryCommand = ''
        foreach ($frame in Get-PSCallStack) {
            $frameCommand = $frame.Command
            if ($frameCommand -match '^[A-Za-z]+-(DM|deviceManager)' -and $frameCommand -notin $dmPlumbing) {
                $entryCommand = $frameCommand
            }
        }
        Assert-DMWriteAllowed -Method $Method -Command $entryCommand
    }
    # ------------------------------------------------------------------------------------------------

    if ($WebSession){
        $session = $WebSession
    } else {
        $session = $script:CurrentOceanstorSession
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
	$JsonBody = $null
	$dmStatus = $null
	try {
		# Preserve the certificate validation choice made when the session was created.
		$invokeParams = @{
			Method      = $Method
			Uri         = $RestURI
			Headers     = $session.Headers
			WebSession  = $session.WebSession
			ContentType = 'application/json'
		}
		if ($PSBoundParameters.ContainsKey('TimeoutSec')) {
			$invokeParams.TimeoutSec = $TimeoutSec
		}
		if ($session.SkipCertificateCheck) {
			$invokeParams.SkipCertificateCheck = $true
		}

		if ($BodyData){
			$JsonBody = ConvertTo-Json $BodyData -Depth 10
			$invokeParams.Body = $JsonBody
		}

		# StatusCodeVariable captures the real HTTP status but only exists on PS 7.4+ (the
		# module targets PS 6.0). Add it only to the Invoke-RestMethod call via a cloned splat
		# so the Invoke-WebRequest fallback below, which reuses $invokeParams, is never handed a
		# parameter it may not support. On hosts without it, success falls back to HTTP 200 --
		# OceanStor reports real failures via the body's error.code, not the HTTP status.
		$restParams = $invokeParams
		if ((Get-Command Invoke-RestMethod).Parameters.ContainsKey('StatusCodeVariable')) {
			$restParams = $invokeParams.Clone()
			$restParams.StatusCodeVariable = 'dmStatus'
		}
		$result = Invoke-RestMethod @restParams

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

		$successStatus = if ($dmStatus) { [int]$dmStatus } else { 200 }
		Write-DMRequestTrace -StartedAt $startedAt -Method $Method -Resource $Resource -Uri $RestURI `
			-BodyData $BodyData -ApiV2:$ApiV2 -Response $result `
			-Session $session -StatusCode $successStatus -RawJsonBody $JsonBody -Headers $session.Headers
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
				$fallbackStatus = if ($rawResponse.PSObject.Properties['StatusCode']) { [int]$rawResponse.StatusCode } else { $null }
				Write-DMRequestTrace -StartedAt $startedAt -Method $Method -Resource $Resource -Uri $RestURI `
					-BodyData $BodyData -ApiV2:$ApiV2 -Response $result `
					-Session $session -StatusCode $fallbackStatus -RawJsonBody $JsonBody -Headers $session.Headers
				return $result
			} catch {
				Write-Verbose "Invoke-WebRequest fallback also failed for '$RestURI': $($_.Exception.Message)"
			}
		}
		# Extract the HTTP status defensively: many exception types (e.g. ArgumentException)
		# have no Response member, which throws under Set-StrictMode if accessed directly.
		$httpStatus = $null
		$responseProp = $originalError.Exception.PSObject.Properties['Response']
		if ($responseProp -and $responseProp.Value) {
			$statusProp = $responseProp.Value.PSObject.Properties['StatusCode']
			if ($statusProp) { try { $httpStatus = [int]$statusProp.Value } catch { $httpStatus = $null } }
		}
		Write-DMRequestTrace -StartedAt $startedAt -Method $Method -Resource $Resource -Uri $RestURI `
			-BodyData $BodyData -ApiV2:$ApiV2 -Exception $originalError.Exception.Message `
			-Session $session -StatusCode $httpStatus -RawJsonBody $JsonBody -Headers $session.Headers
		throw $originalError
	}
}
