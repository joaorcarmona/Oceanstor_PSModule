# HyperMetro SAN Domains

## Scope

SAN HyperMetro domains — the container tying the local array, a remote array,
and an arbitration (quorum) mode together — plus quorum-server association.
REST resource: `HyperMetroDomain`.

## Cmdlets

| Cmdlet | REST operation | Kind |
|---|---|---|
| `Get-DMHyperMetroDomain` | `GET HyperMetroDomain` / `GET HyperMetroDomain/${id}` | Read-only |
| `New-DMHyperMetroDomain` | `POST HyperMetroDomain` | Mutating |
| `Set-DMHyperMetroDomain` | `PUT HyperMetroDomain/${id}` | Mutating |
| `Remove-DMHyperMetroDomain` | `DELETE HyperMetroDomain/${id}` | Mutating |
| `Add-DMQuorumServerToHyperMetroDomain` | `POST HyperMetroDomain/CREATE_ASSOCIATE` | Mutating (changes arbitration) |
| `Remove-DMQuorumServerFromHyperMetroDomain` | `PUT HyperMetroDomain/REMOVE_ASSOCIATE` | Mutating (changes arbitration) |

`New-DMHyperMetroDomain` accepts `-Name`, `-Description`, `-RemoteDevices`,
`-DomainType` (`AA`, `AP`), and `-ApiProperties`. `Set-DMHyperMetroDomain`
accepts `-NewName` and `-Description`. `Remove-DMHyperMetroDomain` supports
`-LocalDelete`. The quorum cmdlets take the domain `-Id`/`-Name` plus
`-QuorumServerId`.

## Common Workflows

```text
Get-DMHyperMetroDomain                      # inspect existing domains
New-DMHyperMetroDomain                      # create (lab / initial setup)
Add-DMQuorumServerToHyperMetroDomain        # attach quorum server
Remove-DMQuorumServerFromHyperMetroDomain   # detach quorum server
Remove-DMHyperMetroDomain                   # tear down (no member pairs)
```

## Examples

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
$storage = Connect-deviceManager -Hostname $storageIP -PassThru -Credential $cred

# Read-only: list domains with arbitration details
Get-DMHyperMetroDomain

# Preview a domain rename
Set-DMHyperMetroDomain -Name 'metro-domain-01' -NewName 'metro-domain-lab' -WhatIf
```

## Safety Notes

- Quorum association changes alter split-brain arbitration for **every pair in
  the domain**. Losing or changing the quorum server on a live domain can
  determine which site keeps serving I/O during a link failure.
- Deleting a domain is only possible after its pairs are removed; never delete
  a pre-existing domain during validation.
- Production HyperMetro deployments usually consume an existing domain; the
  integration workflow requires a configured `DomainId`/`DomainName` and never
  creates or deletes domains on its own.

## Integrity Test Coverage

- Unit: `Tests/Unit/Public/replication-hypermetro-domain-lifecycle.Tests.ps1`
  covers create/modify/remove and both quorum association endpoints.
- Live: `Get-DMHyperMetroDomain` validated read-only against a lab array (one
  existing domain enumerated with correct type). Domain and quorum mutation is
  not exercised by the integration workflow — it consumes a configured
  existing domain only.

## Known Gaps

- No cmdlet wraps quorum server *inventory* (listing available quorum servers
  to obtain `-QuorumServerId`); the ID must come from DeviceManager or
  `-ApiProperties`-level queries.
- Domain/quorum mutation has no gated integration coverage.

## Related Files

- `POSH-Oceanstor/Public/*DMHyperMetroDomain*.ps1`
- `POSH-Oceanstor/Public/Add-DMQuorumServerToHyperMetroDomain.ps1`
- `POSH-Oceanstor/Public/Remove-DMQuorumServerFromHyperMetroDomain.ps1`
- `POSH-Oceanstor/Private/class-OceanstorHyperMetroDomain.ps1`
- `POSH-Oceanstor/Format/OceanstorHyperMetroDomain.format.ps1xml`
