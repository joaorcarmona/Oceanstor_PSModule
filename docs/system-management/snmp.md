# SNMP System Management

## Scope

SNMP protocol configuration, SNMP security policy, SNMP community strings,
SNMP trap servers (notification targets), and SNMPv3 USM users.

## Cmdlets

| Cmdlet | Action | REST resource | Mutating | ShouldProcess |
|---|---|---|---|---:|
| `Get-DMSnmpConfig` | Read SNMP protocol configuration | `common/snmp_protocol` | No | — |
| `Set-DMSnmpConfig` | Modify SNMP protocol configuration | `common/snmp_protocol` (PUT) | Yes | Yes |
| `Get-DMSnmpSecurityPolicy` | Read SNMP security policy | `common/snmp_security_policies` | No | — |
| `Set-DMSnmpSecurityPolicy` | Modify SNMP security policy | `common/snmp_security_policies` (PUT) | Yes | Yes |
| `Set-DMSnmpCommunity` | Set SNMP community string | `SNMP_COMMUNITY` (PUT) | Yes | Yes |
| `Get-DMSnmpTrapServer` | List trap servers or one by `-Id` | `snmp_trap_addr`, `snmp_trap_addr/<id>` | No | — |
| `New-DMSnmpTrapServer` | Add a trap server | `snmp_trap_addr` (POST) | Yes | Yes |
| `Set-DMSnmpTrapServer` | Modify a trap server | `snmp_trap_addr/<id>` (PUT) | Yes | Yes |
| `Remove-DMSnmpTrapServer` | Delete a trap server | `snmp_trap_addr/<id>` (DELETE) | Yes | Yes |
| `Test-DMSnmpTrapServer` | Send a test trap message | `snmp_trap_addr/send_test_trapmsg` (PUT) | Sends traffic | No |
| `Get-DMSnmpUsmUser` | List USM users or one by `-Id` | `snmp_usm`, `snmp_usm/<id>` | No | — |
| `New-DMSnmpUsmUser` | Create an SNMPv3 USM user | `snmp_usm` (POST) | Yes | Yes |
| `Set-DMSnmpUsmUser` | Modify a USM user | `snmp_usm` (PUT) | Yes | Yes |
| `Remove-DMSnmpUsmUser` | Delete a USM user | `snmp_usm/<id>` (DELETE) | Yes | Yes |

Key parameters:

- `New-DMSnmpTrapServer -Address -Port -User -Type -Version [-Property]`
- `New-DMSnmpUsmUser -Name -AuthProtocol -AuthPassword -PrivacyProtocol -PrivacyPassword -UserLevel [-Property]`
- `Set-DMSnmpCommunity -Community [-CommunityPropertyName] [-Property]`
- Community and USM password parameters accept `SecureString` values.

Getters return `OceanStorSnmpConfig`, `OceanStorSnmpSecurityPolicy`,
`OceanStorSnmpTrapServer`, and `OceanStorSnmpUsmUser` typed objects.

## Common Workflows

1. **Audit** — read SNMP config, security policy, trap targets, and USM users.
2. **Add a monitoring target** — create a USM user for the NMS, then register
   the NMS as a trap server and send a test trap.
3. **Rotate SNMP credentials** — update community or USM passwords.

## Examples

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
$storage = Connect-deviceManager -Hostname $storageIP -Credential $cred -PassThru

# Audit current SNMP posture
Get-DMSnmpConfig -WebSession $storage
Get-DMSnmpSecurityPolicy -WebSession $storage
Get-DMSnmpTrapServer -WebSession $storage
Get-DMSnmpUsmUser -WebSession $storage

# Register a new SNMPv3 trap target (preview first)
$auth = Read-Host -AsSecureString -Prompt 'Auth password'
$priv = Read-Host -AsSecureString -Prompt 'Privacy password'
New-DMSnmpUsmUser -WebSession $storage -Name 'nms_v3' -AuthProtocol 'SHA2_256' `
    -AuthPassword $auth -PrivacyProtocol 'AES256' -PrivacyPassword $priv -UserLevel 'AuthPriv' -WhatIf

New-DMSnmpTrapServer -WebSession $storage -Address '192.0.2.10' -Port 162 `
    -User 'nms_v3' -Type 'Trap' -Version 'V3' -WhatIf

# Verify delivery to the new target
Test-DMSnmpTrapServer -WebSession $storage -Address '192.0.2.10' -Port 162 `
    -User 'nms_v3' -Type 'Trap' -Version 'V3'
```

## Safety Notes

- `Set-DMSnmpConfig`, `Set-DMSnmpSecurityPolicy`, and `Set-DMSnmpCommunity`
  are `GlobalSettingMutation` / `AlertingOrMonitoringMutation`: they change
  array-wide monitoring behavior. Do not run them against a shared array
  without a rollback plan.
- Trap servers and USM users are **discrete objects** — the only
  system-management resources in this domain suitable for test-owned
  lifecycle validation (`TestOwnedObjectMutation`): create with a unique
  test name/address, capture the returned ID, delete by that ID.
- Never modify or delete pre-existing trap targets or USM users — they are
  someone's production monitoring.
- `Test-DMSnmpTrapServer` sends a real trap to the specified address. Only
  point it at targets you own.
- Do not disable SNMP.

## Integrity Test Coverage

- Read-only: all four getters are validated by
  `Tests/Integration/Private/ReadValidation.ps1`.
- Mutating: **no integration workflow exists**, although trap servers and USM
  users are good test-owned candidates. The mutators are reported as
  `SkippedUnsafe` in every run until such a workflow exists.
- Unit tests: `Set-SystemConfiguration.Tests.ps1` covers trap server CRUD +
  test trap, protocol/security/community sets, USM user CRUD, SecureString
  handling, and `-WhatIf`.

## Known Gaps

- No integration workflow for a test-owned trap server + USM user lifecycle
  (`IntegrityTestGap` — highest-value candidate in this domain).
- No enable/disable cmdlet for the SNMP service itself (arguably a feature,
  not a gap: disabling SNMP is a hazardous global action).

## Related Files

- `POSH-Oceanstor/Public/*DMSnmp*.ps1`
- `POSH-Oceanstor/Private/class-OceanStorSystemConfiguration.ps1`
- `Tests/Unit/Public/Get-SystemConfiguration.Tests.ps1`
- `Tests/Unit/Public/Set-SystemConfiguration.Tests.ps1`
- `Tests/Integration/Private/ReadValidation.ps1`
