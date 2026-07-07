# Network Safety and Live Validation

Network cmdlets can break management access, NAS/iSCSI data access, or
failover behavior. This page defines what may run against a live array and
under which rules. When in doubt: **read-only is fine, everything else is
not.**

## Safety classification

| Class | Cmdlets | Live validation rule |
|---|---|---|
| ReadOnlyNetworkInventory | `Get-DMPortETH`, `Get-DMPortFc`, `Get-DMPortSAS`, `Get-DMInterfaceModule`, `Get-DMPortBond`, `Get-DMvLan`, `Get-DMLif`, `Get-DMFailoverGroup` | Safe to run live |
| ReadOnlyNetworkStatus | `Get-DMLLDPWorkingMode` | Safe to run live |
| TestOwnedLogicalNetworkMutation | `New-DMFailoverGroup`, `Set-DMFailoverGroup`, `Remove-DMFailoverGroup`, `Add-DMFailoverGroupMember`, `Remove-DMFailoverGroupMember` | Only on objects created by the same run, with guaranteed cleanup |
| VlanMutation | `New-DMvLan`, `Set-DMvLan`, `Remove-DMvLan` | Only a test-owned VLAN on a verified-idle port; otherwise skip |
| DataAccessMutation / ManagementAccessMutation | `New-DMLif`, `Set-DMLif`, `Remove-DMLif` | Do not run live by default |
| BondOrAggregationMutation | `New-DMPortBond`, `Set-DMPortBond`, `Remove-DMPortBond` | Do not run live by default |
| Global network setting | `Set-DMLLDPWorkingMode` | Do not run live by default (no test-owned variant exists) |

There are **no** physical-port or route/gateway mutation cmdlets in this
module; those classes stay unimplemented on purpose.

## Rules

1. Read-only inventory and status getters are normally safe against any array.
2. Physical port changes (enable/disable, MTU, IP, role) are unsafe by default
   — and not implemented here.
3. Management IP and routing changes are unsafe by default — not implemented.
4. Data-access network changes (LIF addresses, home ports, operational status)
   are unsafe by default.
5. Bond, VLAN, and logical-port mutations require a test-owned workflow:
   - use a unique test name prefix (for example `psoceanstor-test-<runid>-`);
   - capture object IDs **immediately** after creation from the returned
     object;
   - clean up in `finally`;
   - delete by captured ID, never by broad name matching;
   - no broad cleanup, ever.
6. Never modify or delete a pre-existing network object or setting. Existing
   configuration is read-only unless the object was provably created by the
   current run.
7. If cleanup fails, report the object type, ID, and name, and suggest the
   exact manual cleanup command.
8. If a test would require changing an existing global or physical network
   setting (LLDP mode, port MTU, existing VLANs/bonds/LIFs), do not run it
   live — mark it unsafe and note what a dedicated lab would need.

## Recommended staged validation order

1. `Connect-deviceManager` (session only).
2. All read-only network getters (`Get-DMPortETH`, `Get-DMPortBond`,
   `Get-DMvLan`, `Get-DMLif`, `Get-DMFailoverGroup`,
   `Get-DMLLDPWorkingMode`, …).
3. `-WhatIf` dry runs of mutators — confirms parameter binding without any
   API call.
4. (Config-gated, dedicated lab only) test-owned failover-group
   create → modify → member add/remove → delete, by captured IDs.
5. (Dedicated lab only) test-owned VLAN / LIF / bond workflows on
   verified-idle ports.

## Example: safe live session

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"

$storage = Connect-deviceManager -Hostname $storageIP -Credential $cred -PassThru

# Read-only inventory — allowed
Get-DMPortETH -WebSession $storage
Get-DMFailoverGroup -WebSession $storage

# Dry run — allowed (no API call is made)
New-DMFailoverGroup -WebSession $storage -Name 'psoceanstor-test-fg' -WhatIf

Disconnect-deviceManager -WebSession $storage
```

## Example: test-owned pattern (dedicated lab only)

```powershell
$fg = $null
try {
    $fg = New-DMFailoverGroup -WebSession $storage -Name "psoceanstor-test-fg-$runId"
    # ... assertions against $fg ...
}
finally {
    if ($fg -and $fg.Id) {
        Remove-DMFailoverGroup -WebSession $storage -Id $fg.Id -Confirm:$false
    }
}
```

## Relationship to the integrity harness

`Tests/Integration/Invoke-GetterIntegrityValidation.ps1` runs the read-only
network getters as part of read validation. Network mutators are **not**
represented in any mutation workflow; the report surfaces them as skipped/not
executed rather than passed — an intentionally skipped unsafe mutator is not
a validated one. Statuses:

- `SkippedUnsafe` — recognized as unsafe to run against a live array.
- `NotConfigured` — mutation testing not acknowledged in
  `IntegrityValidationConfig.psd1` (`AllowMutatingTests`).
- `NotRequested` — runner invoked without `-RunMutatingTests`.
- `Blocked` / `NotExecuted` — command has no workflow representation.
