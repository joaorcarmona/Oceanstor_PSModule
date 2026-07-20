# Prompt: repeat the supervised bond + 4 VLANs + 4 role-LIFs live validation

Paste this whole file as the task prompt in a new Claude Code session against this repo
(`POSH-Oceanstor`) to re-run the same operator-supervised live validation performed on
2026-07-09 (see `CHANGELOG.md`, "Deferred" section, and commit `55ba8bd`).

## Persona / ground rules (must hold for the whole session)

- Act as a senior storage administrator / cautious validation engineer.
- Never print, log, or write to any file the credential object, password, session token,
  cookie, or auth header. Load creds with:
  ```powershell
  $cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
  ```
- Do not push, tag, publish, merge, rebase, switch branches, or create branches.
- Use only test-owned objects with a unique prefix (`dm_integrity_<runId>_`). Capture every
  created object's ID immediately. Clean up strictly by captured ID, in a `finally` block,
  in **exact reverse creation order** (LIFO): LIFs → VLANs → bond.
- Never broad-clean by name pattern against the live array outside of the objects this run
  itself created. Never touch any pre-existing object (other LUNs, LIFs, VLANs, bonds,
  failover groups, users, roles, SNMP/syslog/NTP/DNS, replication/HyperMetro pairs, etc.).
- If cleanup fails or ordering is unclear, stop and report — do not improvise a broader delete.
- Do not put the lab IP in any public doc; only the scratch script (not committed) may use it.
  Public doc examples must use `$storageIP = 'StorageIP'`.
- Commit at the end with a clear message once evidence is written to
  `CHANGELOG.md`. Do not push.

## Task

On the lab array (`10.10.10.24`), using ports `CTE0.A.IOM0.P2` and `CTE0.A.IOM0.P3`
(front-end, link-down, unassociated — re-verify this read-only before touching anything):

1. Create a bond port with those two members.
2. Create VLANs `123`, `124`, `125`, `126` on the new bond.
3. Create four LIFs, one per VLAN, `HomePortType = 8` (VLAN):
   - `10.123.10.1/24` — Role **Management** (Role code 1) — home VLAN 123
   - `10.124.10.1/24` — Role **Service** (Role code 2) — home VLAN 124
   - `10.125.10.1/24` — Role **Replication** (Role code 4) — home VLAN 125
   - `10.126.10.1/24` — Role **Management + Service** (Role code 3) — home VLAN 126
4. Validate everything: read back the bond, all 4 VLANs, and all 4 LIFs; confirm role, IP,
   mask, and home-port/VLAN match what was requested.
5. **Modify two already-validated LIFs, still before teardown:**
   - On the LIF whose IP is `10.124.10.1`, add default gateway `10.124.10.254`
     (`Set-DMLif -IPv4Gateway '10.124.10.254'`).
   - On the LIF whose IP is `10.123.10.1`, change its IP to `10.123.10.100`
     (`Set-DMLif -IPv4Address '10.123.10.100'`).
   - `Set-DMLif` reports API failures as **non-terminating** errors — a modify call can
     appear to succeed with no exception thrown while the array silently rejected it. Do
     **not** trust the call's return value alone: immediately re-read each modified LIF
     (`Get-DMLif`) and confirm the gateway/IP actually changed on the array before treating
     the step as successful.
6. Validate everything again, including the two modifications above (re-read both LIFs and
   confirm the new gateway and new IP are actually present).
7. Delete everything in exact reverse order: LIF 126 → 125 → 124 → 123, then VLAN 126 → 125 →
   124 → 123, then the bond. Verify zero leftover test objects and unchanged port state
   afterward. Teardown must run unconditionally (e.g. from a `finally` block) even if the
   modify/validate steps above fail or abort.
8. Record the outcome in `CHANGELOG.md` and commit (no push).

## Known pitfalls from the last run (avoid repeating them)

- **`OceanStorLIF` has no `Name` property** — the LIF's own name is only exposed as
  `'LIF Name'` (bracket/dot access: `$lif.'LIF Name'`). Checking `$lif.Name` after
  `New-DMLif`/`Get-DMLif` will look empty even though the LIF was created, and will make a
  correctly-created LIF look like `CREATE-FAIL` — aborting mid-run and leaving a real
  leftover LIF (which then blocks `Remove-DMvLan` with `1073813505` and, transitively,
  `Remove-DMPortBond` with `1073801985`). Always test success via `'LIF Name'` or `.Id`.
- **`Get-DMPortBond`'s `'Port List'` property reads empty** — don't gate logic on it; confirm
  bond membership via the port's own `'Port Bond Id'` field instead.
- **`Get-DMvLan`'s `Tag` property reads empty** — match VLANs by `Name` (`<port>.<tag>`
  suffix, e.g. `\.123$`), not by `Tag`.
- Port "front-end" surfaces as `'Logic Type'` (not `'Logical Type'`) with value
  `'host port/service port'`.
- The array enforces teardown order server-side (this is a feature, not a bug): it will
  refuse `Remove-DMvLan` while any LIF is homed on it, and refuse `Remove-DMPortBond` while
  any VLAN is parented on it. If cleanup hits either error, find the still-attached child by
  read-only `Get-DMLif`/`Get-DMvLan` filtered on the run's own object names/IDs, remove it,
  then retry the parent removal — never skip straight to a broader query.
- **`Set-DMLif` always `PUT`s the bare `lif` collection resource, never `lif/{id}`** — unlike
  its siblings `Set-DMPortBond` (`PUT bond_port/{id}`) and `Set-DMFailoverGroup`
  (`PUT failovergroup/{id}`), which are path-scoped by Id whenever one is known. On the lab
  array this makes the API reject the update with error `1077948993` ("The object name
  already exists"), and because `Set-DMLif` swallows API errors as non-terminating
  (`catch { $PSCmdlet.WriteError($_) }`), the call does not throw — it just silently fails to
  apply. This was observed on both requested modifications in the 2026-07-09 repeat run (see
  `CHANGELOG.md`) and is logged as `NeedsInvestigation`, not yet fixed in
  `Set-DMLif.ps1`. **Expect the two modify steps in this run to fail the same way** unless the
  module has since been patched; the read-back check in step 5 above exists specifically to
  catch this rather than trust the call's apparent success.

## Reference implementation (known-good, from the corrected 2026-07-09 run)

Save as a scratch script (e.g. under the session scratchpad, not committed) and run it
interactively so you can watch each phase before cleanup fires:

```powershell
# Supervised, operator-authorized full network-stack lifecycle validation.
# Bond(CTE0.A.IOM0.P2+P3) -> VLANs 123/124/125/126 -> 4 LIFs (roles
# management / service / replication / management+service) -> validate ->
# delete everything in exact reverse creation order (LIFO, in finally).
$ErrorActionPreference = 'Stop'

Import-Module .\POSH-Oceanstor\POSH-Oceanstor.psd1 -Force
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
$s = Connect-deviceManager -Hostname '10.10.10.24' -PassThru -Credential $cred -SkipCertificateCheck

$targetLocations = @('CTE0.A.IOM0.P2', 'CTE0.A.IOM0.P3')
$runId = Get-Date -Format yyyyMMddHHmmss
$bondName = "dm_integrity_${runId}_bd"
$vlanTags = @(123, 124, 125, 126)
# Role codes: 1 = management, 2 = service, 3 = management+service, 4 = replication
$lifPlan = @(
    @{ Tag = 123; Role = 1; RoleLabel = 'management';         Ip = '10.123.10.1' },
    @{ Tag = 124; Role = 2; RoleLabel = 'service';            Ip = '10.124.10.1' },
    @{ Tag = 125; Role = 4; RoleLabel = 'replication';        Ip = '10.125.10.1' },
    @{ Tag = 126; Role = 3; RoleLabel = 'management+service'; Ip = '10.126.10.1' }
)
$mask = '255.255.255.0'

# LIFO stack of created objects for reverse-order teardown.
$created = [System.Collections.Generic.Stack[pscustomobject]]::new()

try {
    # ---- Phase A: read-only invariants ----
    $ethPorts = @(Get-DMPortETH -WebSession $s)
    $ports = foreach ($loc in $targetLocations) {
        $match = @($ethPorts | Where-Object { $_.Location -eq $loc })
        if ($match.Count -ne 1) { throw "GUARD-STOP: port '$loc' resolved to $($match.Count) objects; expected exactly 1." }
        $match[0]
    }
    $allVlans = @(Get-DMvLan -WebSession $s)
    $allBonds = @(Get-DMPortBond -WebSession $s)
    $allLifs  = @(Get-DMLif -WebSession $s)
    Write-Output ("SNAPSHOT: bonds={0} vlans={1} lifs={2}" -f $allBonds.Count, $allVlans.Count, $allLifs.Count)

    foreach ($p in $ports) {
        if ("$($p.'Logic Type')" -notmatch 'host port|service port|front') { throw "GUARD-STOP: $($p.Location) logic type '$($p.'Logic Type')' not front-end; refusing." }
        if ("$($p.'Running Status' ?? $p.RunningStatus)" -notmatch 'down') { throw "GUARD-STOP: $($p.Location) is not link down; refusing." }
        if ("$($p.'Port Bond Id')".Trim()) { throw "GUARD-STOP: $($p.Location) already bonded; refusing." }
        if (@(Get-DMLif -WebSession $s -HomePortId $p.Id).Count -gt 0) { throw "GUARD-STOP: $($p.Location) hosts LIF(s); refusing." }
        if (@($allVlans | Where-Object { $_.'Port Id' -eq $p.Id }).Count -gt 0) { throw "GUARD-STOP: $($p.Location) parents VLAN(s); refusing." }
        Write-Output ("INVARIANTS OK {0}: Id={1} front-end, link down, unassociated" -f $p.Location, $p.Id)
    }

    foreach ($t in $vlanTags) {
        if (@($allVlans | Where-Object { "$($_.Tag)" -eq "$t" -or $_.Name -match "\.$t$" }).Count -gt 0) { throw "GUARD-STOP: pre-existing VLAN tag $t found; refusing." }
    }
    foreach ($l in $lifPlan) {
        if (@($allLifs | Where-Object { $_.'IPv4 Address' -eq $l.Ip -or $_.IPV4ADDR -eq $l.Ip }).Count -gt 0) { throw "GUARD-STOP: pre-existing LIF already uses $($l.Ip); refusing." }
    }
    if (@($allBonds | Where-Object { $_.Name -eq $bondName }).Count -gt 0) { throw "GUARD-STOP: bond '$bondName' already exists; refusing." }
    Write-Output "PRECHECK: no tag/IP/name collisions."

    # ---- Phase B1: bond ----
    $bond = New-DMPortBond -WebSession $s -Name $bondName -PortIdList @($ports.Id) -Confirm:$false
    if (-not $bond -or -not $bond.Id) { throw "CREATE-FAIL: bond returned no ID." }
    $created.Push([pscustomobject]@{ Kind = 'Bond'; Id = [string]$bond.Id; Name = $bond.Name })
    Write-Output ("CREATED BOND Id={0} Name={1}" -f $bond.Id, $bond.Name)

    # ---- Phase B2: VLANs 123..126 on the bond (PortType 7 = bond) ----
    $vlanByTag = @{}
    foreach ($t in $vlanTags) {
        $vlan = New-DMvLan -WebSession $s -Tag $t -PortType 7 -PortId ([string]$bond.Id) -Confirm:$false
        if (-not $vlan -or -not $vlan.Id) { throw "CREATE-FAIL: VLAN $t returned no ID." }
        $created.Push([pscustomobject]@{ Kind = 'Vlan'; Id = [string]$vlan.Id; Name = $vlan.Name })
        $vlanByTag[$t] = $vlan
        Write-Output ("CREATED VLAN{0} Id={1} Name={2}" -f $t, $vlan.Id, $vlan.Name)
    }

    # ---- Phase B3: LIFs on each VLAN (HomePortType 8 = VLAN) ----
    foreach ($l in $lifPlan) {
        $lifName = "dm_integrity_${runId}_l$($l.Tag)"
        $vlanId = [string]$vlanByTag[$l.Tag].Id
        $lif = New-DMLif -WebSession $s -Name $lifName -AddressFamily 0 `
            -IPv4Address $l.Ip -IPv4Mask $mask -Role $l.Role `
            -HomePortType 8 -HomePortId $vlanId -Confirm:$false
        # OceanStorLIF exposes the name as 'LIF Name', not 'Name'.
        if (-not $lif -or -not ($lif.'LIF Name' ?? $lif.Id)) { throw "CREATE-FAIL: LIF $lifName returned no object." }
        $lifId = [string]($lif.Id ?? '')
        $created.Push([pscustomobject]@{ Kind = 'Lif'; Id = $lifId; Name = $lifName })
        Write-Output ("CREATED LIF {0} Id={1} Role={2} Ip={3} HomeVlan={4}" -f $lifName, $lifId, $l.RoleLabel, $l.Ip, $vlanByTag[$l.Tag].Name)
    }

    # ---- Phase B4: validation read-backs ----
    Write-Output '--- VALIDATION ---'
    $bondRb = @(Get-DMPortBond -WebSession $s | Where-Object { $_.Name -eq $bondName })
    Write-Output ("VALIDATE BOND: found={0} Running={1} Health={2}" -f $bondRb.Count, ($bondRb[0].'Running Status' ?? $bondRb[0].RunningStatus), ($bondRb[0].'Health Status' ?? $bondRb[0].HealthStatus))
    foreach ($t in $vlanTags) {
        $v = Get-DMvLan -WebSession $s -Id ([string]$vlanByTag[$t].Id)
        Write-Output ("VALIDATE VLAN{0}: Name={1} Running={2}" -f $t, $v.Name, ($v.'Running Status' ?? $v.RunningStatus))
    }
    foreach ($l in $lifPlan) {
        $lifName = "dm_integrity_${runId}_l$($l.Tag)"
        $rb = @(Get-DMLif -WebSession $s | Where-Object { $_.'LIF Name' -eq $lifName })
        if ($rb.Count -ne 1) { throw "VALIDATE-FAIL: LIF $lifName not found on read-back." }
        Write-Output ("VALIDATE LIF {0}: Role={1} Ip={2} Mask={3} HomePort={4} Running={5}" -f $lifName, ($rb[0].Role ?? $rb[0].ROLE), ($rb[0].'IPv4 Address' ?? $rb[0].IPV4ADDR), ($rb[0].'IPv4 Mask' ?? $rb[0].IPV4MASK), ($rb[0].'Home Port Name' ?? $rb[0].HOMEPORTNAME), ($rb[0].'Running Status' ?? $rb[0].RunningStatus))
    }
    Write-Output 'RESULT: full stack create+validate Passed'

    # ---- Phase B5: modify two already-validated LIFs ----
    Write-Output '--- MODIFY ---'
    $lifByTag = @{}
    foreach ($l in $lifPlan) {
        $lifByTag[$l.Tag] = "dm_integrity_${runId}_l$($l.Tag)"
    }
    $lif124 = @(Get-DMLif -WebSession $s | Where-Object { $_.'LIF Name' -eq $lifByTag[124] })[0]
    $lif123 = @(Get-DMLif -WebSession $s | Where-Object { $_.'LIF Name' -eq $lifByTag[123] })[0]
    if (-not $lif124 -or -not $lif123) { throw "MODIFY-FAIL: could not resolve LIF .124 or .123 before modify." }

    Set-DMLif -WebSession $s -Id $lif124.Id -IPv4Gateway '10.124.10.254' -Confirm:$false
    Set-DMLif -WebSession $s -Id $lif123.Id -IPv4Address '10.123.10.100' -Confirm:$false

    # ---- Phase B6: re-validate — do NOT trust Set-DMLif's return value; Set-DMLif
    # reports API failures as non-terminating (catch { $PSCmdlet.WriteError($_) }),
    # so a rejected update does not throw. Read back and check the actual value.
    Write-Output '--- RE-VALIDATE MODIFY ---'
    $lif124rb = Get-DMLif -WebSession $s -Id $lif124.Id
    $lif123rb = Get-DMLif -WebSession $s -Id $lif123.Id
    $gatewayOk = ($lif124rb.'IPv4 Gateway' -eq '10.124.10.254')
    $ipOk = ($lif123rb.'IPv4 Address' -eq '10.123.10.100')
    Write-Output ("VALIDATE MODIFY .124 gateway: expected=10.124.10.254 actual={0} ok={1}" -f $lif124rb.'IPv4 Gateway', $gatewayOk)
    Write-Output ("VALIDATE MODIFY .123 address: expected=10.123.10.100 actual={0} ok={1}" -f $lif123rb.'IPv4 Address', $ipOk)
    if (-not $gatewayOk -or -not $ipOk) {
        throw "MODIFY-VALIDATE-FAIL: one or both Set-DMLif changes did not apply on the array (see CHANGELOG.md Set-DMLif NeedsInvestigation finding)."
    }
    Write-Output 'RESULT: LIF modify+re-validate Passed'
}
finally {
    Write-Output '--- TEARDOWN (reverse creation order) ---'
    while ($created.Count -gt 0) {
        $obj = $created.Pop()
        try {
            switch ($obj.Kind) {
                'Lif'  { if ($obj.Id) { Remove-DMLif -WebSession $s -Name $obj.Name -Id $obj.Id -Confirm:$false } else { Remove-DMLif -WebSession $s -Name $obj.Name -Confirm:$false } }
                'Vlan' { Remove-DMvLan -WebSession $s -Id $obj.Id -Confirm:$false }
                'Bond' { Remove-DMPortBond -WebSession $s -Id $obj.Id -Confirm:$false }
            }
            Write-Output ("CLEANUP: removed {0} {1} (Id={2})" -f $obj.Kind, $obj.Name, $obj.Id)
        }
        catch {
            Write-Output ("CLEANUP-FAILED: {0} {1} (Id={2}) :: {3}" -f $obj.Kind, $obj.Name, $obj.Id, $_.Exception.Message)
        }
    }
    try {
        $leftLifs  = @(Get-DMLif -WebSession $s | Where-Object { $_.'LIF Name' -like "dm_integrity_${runId}_*" })
        $leftVlans = @(Get-DMvLan -WebSession $s | Where-Object { $_.Name -match '\.(12[3-6])$' })
        $leftBonds = @(Get-DMPortBond -WebSession $s | Where-Object { $_.Name -eq $bondName })
        Write-Output ("VERIFY-AFTER-CLEANUP: test LIFs={0} test VLANs={1} test bonds={2}" -f $leftLifs.Count, $leftVlans.Count, $leftBonds.Count)
        foreach ($loc in $targetLocations) {
            $p = @(Get-DMPortETH -WebSession $s | Where-Object Location -eq $loc)[0]
            Write-Output ("VERIFY-PORT {0}: Running={1} BondId='{2}'" -f $p.Location, ($p.'Running Status' ?? $p.RunningStatus), $p.'Port Bond Id')
        }
    }
    catch { Write-Output "VERIFY-AFTER-CLEANUP failed: $($_.Exception.Message)" }
    try { Disconnect-deviceManager -WebSession $s -Confirm:$false } catch { Write-Output "disconnect failed: $($_.Exception.Message)" }
}
```

## Expected report at the end

- Pre-flight invariant results for both ports.
- Created object IDs (bond, 4 VLANs, 4 LIFs).
- Validation read-back results (role/IP/mask/home-VLAN per LIF).
- Result of the two `Set-DMLif` modify steps (gateway on `.124`, IP change on `.123`),
  **based on read-back, not on whether the call threw** — state plainly whether each change
  actually applied on the array.
- Teardown order and zero-leftover verification.
- Any new/repeated field-mapping findings, logged as `NeedsInvestigation` in
  `CHANGELOG.md` (do not fix them as part of this validation task unless separately
  asked).
- Commit hash, with confirmation nothing was pushed and no pre-existing object was touched.
