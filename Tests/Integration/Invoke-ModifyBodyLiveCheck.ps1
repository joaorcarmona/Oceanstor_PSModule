<#
.SYNOPSIS
    Focused, reversible live re-confirmation that the "missing Mandatory ID body field"
    modify fixes are accepted by real OceanStor firmware.

.DESCRIPTION
    A latent defect class (fixed across Phase 1 and Phase 2) is a Set-DM* modify cmdlet
    that sends the object ID only in the URL path and omits it from the request body, even
    though the REST reference Parameters table marks ID Mandatory. The array rejects such a
    payload with error 50331651 ("The entered parameter is incorrect") or times out with
    1077949001. The doc's terse example body is not the contract; the Parameters table is.

    This runner exercises the fixed cmdlets against a live array using the smallest safe
    footprint. For each cmdlet it creates ONE run-unique, test-owned throwaway object,
    modifies a benign field (description), reads it back to confirm the change, and removes
    the object by its captured ID in a finally block. Because each Set-DM* cmdlet runs
    Assert-DMApiSuccess internally, a rejected body makes the cmdlet THROW; a PASS therefore
    means the array genuinely accepted the echoed Mandatory ID.

    Covered cmdlets (extend the $checks list to add more):
      - Set-DMFailoverGroup     (PUT failovergroup/{id},      REST 4.6.9.3.7)
      - Set-DMRole              (PUT role/{id},               REST 4.3.6.3.1)
      - Set-DMHyperCDPSchedule  (PUT SNAPSHOT_SCHEDULE/{id},  REST 4.9.12.3.3)

    Safety contract (mirrors Invoke-GetterIntegrityValidation.ps1):
      - only run-unique, test-owned objects are created; a name collision aborts that check
        loudly and creates nothing;
      - each object's ID is captured from an immediate read-back and removed by that captured
        ID in a finally block; pre-existing objects are never modified, matched by pattern,
        or cleaned;
      - nothing DR-related (HyperMetro / Replication) is touched.

    The module is bootstrapped by dot-sourcing the sources into an in-memory module (classes
    first, so [OutputType([...])] class literals resolve) rather than Import-Module, which
    the module's OutputType class literals break. This mirrors the getter-integrity runner.

.PARAMETER Hostname
    Hostname or IP address of the OceanStor array to validate.

.PARAMETER Credential
    Optional PSCredential for an unattended run. When omitted, a secure credential prompt
    is used (Connect-deviceManager -Secure).

.PARAMETER SkipCertificateCheck
    Disables TLS certificate validation for the login and all session requests. Use for
    lab/test arrays with self-signed certificates.

.EXAMPLE
    # Unattended, using a stored credential (lab array with a self-signed certificate):
    $cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
    ./Tests/Integration/Invoke-ModifyBodyLiveCheck.ps1 -Hostname 10.10.10.24 -Credential $cred -SkipCertificateCheck

.EXAMPLE
    # Interactive credential prompt:
    ./Tests/Integration/Invoke-ModifyBodyLiveCheck.ps1 -Hostname storage.lab.example -SkipCertificateCheck

.NOTES
    Filename: Invoke-ModifyBodyLiveCheck.ps1
    Live-confirmed 2026-07-17 against a V600R005C27 lab array. Exit code 0 = all passed,
    1 = at least one check failed or was blocked.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Hostname,

    [pscredential]$Credential,

    [switch]$SkipCertificateCheck
)

$ErrorActionPreference = 'Stop'
$runId = Get-Date -Format 'yyyyMMddHHmmss'
$results = [System.Collections.Generic.List[object]]::new()

function Add-Result {
    param([string]$Fix, [string]$Status, [string]$Detail)
    $results.Add([pscustomobject]@{ Fix = $Fix; Status = $Status; Detail = $Detail })
    $colour = switch ($Status) { 'PASS' { 'Green' } 'FAIL' { 'Red' } default { 'Yellow' } }
    Write-Host ("[{0}] {1} - {2}" -f $Status, $Fix, $Detail) -ForegroundColor $colour
}

# ---- Bootstrap the module by dot-sourcing sources into an in-memory module. Load every
# class first (class-OceanstorSession first so other classes' constructors resolve, then the
# rest), then the non-class private helpers, then the public commands. This ordering lets
# [OutputType([SomeClass])] literals resolve at parse time, which plain Import-Module of the
# manifest does not guarantee. Globbing (rather than an explicit helper list) auto-includes
# any newly added Private helper. ----
$moduleRoot = (Resolve-Path -LiteralPath (Join-Path (Split-Path -Parent $PSScriptRoot) '..\POSH-Oceanstor')).Path

$validationModule = New-Module -Name ModifyBodyLiveCheck -ArgumentList $moduleRoot -ScriptBlock {
    param($root)

    . (Join-Path $root 'Private\class-OceanstorSession.ps1')
    Get-ChildItem -LiteralPath (Join-Path $root 'Private') -Filter 'class-*.ps1' |
        Where-Object Name -ne 'class-OceanstorSession.ps1' |
        ForEach-Object { . $_.FullName }
    Get-ChildItem -LiteralPath (Join-Path $root 'Private') -Filter '*.ps1' |
        Where-Object Name -notlike 'class-*.ps1' |
        ForEach-Object { . $_.FullName }
    Get-ChildItem -LiteralPath (Join-Path $root 'Public') -Filter '*.ps1' |
        ForEach-Object { . $_.FullName }

    Export-ModuleMember -Function '*'
}
Import-Module $validationModule -Force

try {
    Write-Host "Connecting to $Hostname ..." -ForegroundColor Cyan
    $session = if ($Credential) {
        Connect-deviceManager -Hostname $Hostname -PassThru -Credential $Credential -SkipCertificateCheck:$SkipCertificateCheck
    }
    else {
        Connect-deviceManager -Hostname $Hostname -PassThru -Secure -SkipCertificateCheck:$SkipCertificateCheck
    }
    Write-Host "Connected. Array version: $($session.Version)" -ForegroundColor Cyan

    # ===== Set-DMFailoverGroup (PUT failovergroup/{id}, REST 4.6.9.3.7) =====
    $fgName = "dm_modbody_${runId}_fg"
    $fgId = $null
    try {
        if (@(Get-DMFailoverGroup -WebSession $session -Name $fgName).Count -gt 0) {
            throw "A failover group named '$fgName' already exists; aborting to avoid claiming a pre-existing object."
        }
        New-DMFailoverGroup -WebSession $session -Name $fgName -Description "modbody create $runId" -FailoverGroupServiceType 0 -Confirm:$false | Out-Null
        $created = @(Get-DMFailoverGroup -WebSession $session -Name $fgName)
        if ($created.Count -eq 0 -or -not $created[0].Id) { throw 'Created failover group could not be read back with an ID.' }
        $fgId = [string]$created[0].Id

        Set-DMFailoverGroup -WebSession $session -Id $fgId -Description "modbody updated $runId" -Confirm:$false | Out-Null
        $after = @(Get-DMFailoverGroup -WebSession $session -Id $fgId)
        if ($after.Count -eq 0 -or $after[0].Description -ne "modbody updated $runId") {
            throw "read-back mismatch: expected 'modbody updated $runId', found '$($after[0].Description)'."
        }
        Add-Result -Fix 'Set-DMFailoverGroup (4.6.9.3.7)' -Status 'PASS' -Detail "modify accepted, description updated on id $fgId"
    }
    catch { Add-Result -Fix 'Set-DMFailoverGroup (4.6.9.3.7)' -Status 'FAIL' -Detail $_.Exception.Message }
    finally {
        if ($fgId) { try { Remove-DMFailoverGroup -WebSession $session -Id $fgId -Confirm:$false | Out-Null; Write-Host "  cleaned up failover group $fgId" -ForegroundColor DarkGray } catch { Write-Warning "cleanup failed for failover group ${fgId}: $($_.Exception.Message)" } }
    }

    # ===== Set-DMRole (PUT role/{id}, REST 4.3.6.3.1) =====
    $roleName = "dm_modbody_${runId}_rol"
    $roleId = $null
    try {
        if (@(Get-DMRole -WebSession $session | Where-Object Name -EQ $roleName).Count -gt 0) {
            throw "A role named '$roleName' already exists; aborting to avoid claiming a pre-existing object."
        }
        # A role with no permission entry is rejected (50331651); supply a minimal read-only permit.
        New-DMRole -WebSession $session -Name $roleName -Description "modbody create $runId" -RoleOwnerGroup '1' -PermitList 'lun:lun_R;' -Confirm:$false | Out-Null
        $created = @(Get-DMRole -WebSession $session | Where-Object Name -EQ $roleName)
        if ($created.Count -eq 0 -or -not $created[0].Id) { throw 'Created role could not be read back with an ID.' }
        $roleId = [string]$created[0].Id

        Set-DMRole -WebSession $session -Id $roleId -Description "modbody updated $runId" -Confirm:$false | Out-Null
        $after = @(Get-DMRole -WebSession $session | Where-Object Id -EQ $roleId)
        if ($after.Count -eq 0 -or $after[0].Description -ne "modbody updated $runId") {
            throw "read-back mismatch: expected 'modbody updated $runId', found '$($after[0].Description)'."
        }
        Add-Result -Fix 'Set-DMRole (4.3.6.3.1)' -Status 'PASS' -Detail "modify accepted, description updated on id $roleId"
    }
    catch { Add-Result -Fix 'Set-DMRole (4.3.6.3.1)' -Status 'FAIL' -Detail $_.Exception.Message }
    finally {
        if ($roleId) { try { Remove-DMRole -WebSession $session -Id $roleId -Confirm:$false | Out-Null; Write-Host "  cleaned up role $roleId" -ForegroundColor DarkGray } catch { Write-Warning "cleanup failed for role ${roleId}: $($_.Exception.Message)" } }
    }

    # ===== Set-DMHyperCDPSchedule (PUT SNAPSHOT_SCHEDULE/{id}, REST 4.9.12.3.3) =====
    $schedName = "dm_modbody_${runId}_hcdp"
    $schedId = $null
    try {
        if (@(Get-DMHyperCDPSchedule -WebSession $session -Name $schedName | Where-Object Name -EQ $schedName).Count -gt 0) {
            throw "A HyperCDP schedule named '$schedName' already exists; aborting to avoid claiming a pre-existing object."
        }
        $new = New-DMHyperCDPSchedule -WebSession $session -Name $schedName -Description "modbody create $runId" -FrequencyValueSeconds 3600 -FrequencySnapshotCount 2
        $schedId = if ($new -and $new.Id) { [string]$new.Id } else { [string](@(Get-DMHyperCDPSchedule -WebSession $session -Name $schedName | Where-Object Name -EQ $schedName)[0].Id) }
        if (-not $schedId) { throw 'Created HyperCDP schedule could not be read back with an ID.' }

        Set-DMHyperCDPSchedule -WebSession $session -ScheduleId $schedId -Description "modbody updated $runId" -Confirm:$false | Out-Null
        $after = @(Get-DMHyperCDPSchedule -WebSession $session -Id $schedId)
        if ($after.Count -eq 0 -or $after[0].Description -ne "modbody updated $runId") {
            throw "read-back mismatch: expected 'modbody updated $runId', found '$($after[0].Description)'."
        }
        Add-Result -Fix 'Set-DMHyperCDPSchedule (4.9.12.3.3)' -Status 'PASS' -Detail "modify accepted, description updated on id $schedId"
    }
    catch { Add-Result -Fix 'Set-DMHyperCDPSchedule (4.9.12.3.3)' -Status 'FAIL' -Detail $_.Exception.Message }
    finally {
        if ($schedId) { try { Remove-DMHyperCDPSchedule -WebSession $session -ScheduleId $schedId -Confirm:$false | Out-Null; Write-Host "  cleaned up HyperCDP schedule $schedId" -ForegroundColor DarkGray } catch { Write-Warning "cleanup failed for HyperCDP schedule ${schedId}: $($_.Exception.Message)" } }
    }
}
finally {
    if ($session) { try { Disconnect-deviceManager -WebSession $session } catch { Write-Verbose "disconnect failed: $_" } }
    Remove-Module -Name ModifyBodyLiveCheck -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host '===== Modify-body live validation summary =====' -ForegroundColor Cyan
$results | Format-Table -AutoSize | Out-String | Write-Host
if (@($results | Where-Object Status -ne 'PASS').Count -gt 0) { exit 1 } else { exit 0 }
