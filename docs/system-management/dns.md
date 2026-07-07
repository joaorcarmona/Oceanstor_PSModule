# DNS System Management

## Scope

Array DNS server configuration.

## Cmdlets

| Cmdlet | Action | REST resource | Mutating | ShouldProcess |
|---|---|---|---|---:|
| `Get-DMdnsServer` | Read configured DNS servers | `dns_server` | No | — |
| `Set-DMdnsServer` | Set the DNS server list | `dns_server` (PUT) | Yes | Yes |

Key parameters:

- `Set-DMdnsServer -DNSserver <string[]>` — replaces the DNS server list.

`Get-DMdnsServer` returns `OceanStorDnsServer` objects, one per configured
address, with `Address` and `Position` (1-based) properties. **Breaking
change:** it previously returned a `System.Collections.Hashtable` keyed by
`"DNS Server N"`; scripts indexing into that hashtable must switch to the
typed properties instead (see `RELEASE_NOTES.md` at release time).

## Common Workflows

1. **Audit** — read current DNS servers.
2. **Repoint DNS** — replace the server list during an infrastructure change.

## Examples

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
$storage = Connect-deviceManager -Hostname $storageIP -Credential $cred -PassThru

# Audit
Get-DMdnsServer -WebSession $storage

# Replace DNS servers — capture the old value first, preview, then apply
$before = Get-DMdnsServer -WebSession $storage
Set-DMdnsServer -WebSession $storage -DNSserver '192.0.2.53', '192.0.2.54' -WhatIf
```

## Safety Notes

- `Set-DMdnsServer` is `GlobalSettingMutation`: DNS is a single global
  setting with no test-owned variant. Breaking it can break NTP-by-name,
  LDAP, syslog-by-name, and alert delivery.
- It is deliberately listed in the integrity harness `excludedCommands`
  (`MutationValidation.ps1`) so it is never exercised live.
- If a change is required, capture the previous value first and keep a
  console session open until name resolution is confirmed working.

## Integrity Test Coverage

- Read-only: `Get-DMdnsServer` is validated by `ReadValidation.ps1`
  (expected type `OceanStorDnsServer`).
- Mutating: `Set-DMdnsServer` is excluded from live validation by design —
  correct and intentional.
- Unit tests: `Tests/Unit/Public/Get-SystemConfiguration.Tests.ps1` covers
  `Get-DMdnsServer` (REST routing, typed `OceanStorDnsServer` output with
  1-based position, JSON-encoded and array address payloads) and
  `Set-SystemConfiguration.Tests.ps1` covers `Set-DMdnsServer` (PUT body
  shape, IPv4 validation rejection, `-WhatIf` no-API-call guard).

## Known Gaps

- No DNS domain / search-suffix management (only the server list).

## Related Files

- `POSH-Oceanstor/Public/Get-DMdnsServer.ps1`, `Set-DMdnsServer.ps1`
- `Tests/Integration/Private/ReadValidation.ps1`
- `Tests/Integration/Private/MutationValidation.ps1` (exclusion list)
