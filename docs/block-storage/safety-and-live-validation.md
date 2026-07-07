# Block Storage Safety and Live Validation

Block-storage commands can change host access to data. Treat every mutator as
storage-impacting unless it only reads state.

## Safety Classes

| Class | Meaning | Live validation rule |
|---|---|---|
| `ReadOnlyBlockInventory` | Getter or performance read | Safe to run live |
| `TestOwnedBlockMutation` | Creates, modifies, maps, or deletes an object created by the same run | Allowed only with `-RunMutatingTests` and config gates |
| `AccessPathMutation` | Changes host, initiator, mapping, or mapping-view access | Test-owned only; production changes require a change plan |
| `DataLossRisk` | Deletes or rolls back data-bearing objects | Avoid outside isolated test-owned resources |

## Rules

1. Read-only inventory commands are generally safe.
2. Mutating commands require explicit user intent.
3. Live mutation tests must be opt-in with `-RunMutatingTests`.
4. Workflows must use test-owned resources only.
5. Cleanup must use captured IDs or exact captured identities only.
6. Do not delete or modify pre-existing LUNs, hosts, initiators, LUN groups,
   mapping views, or protection groups.
7. Use `-WhatIf` when learning mutators.
8. Avoid destructive operations on shared or production arrays.

## Domain Risks

- `Remove-DMLun` can delete block storage data.
- Unmapping cmdlets can remove host access to a LUN.
- Host, host-group, and initiator changes can alter production connectivity.
- Mapping-view deletion can break access for every object in that view.
- Protection-group changes can affect protection relationships and snapshots.

## Integrity Harness Behavior

Read-only runs call getters only. Mutating runs require both the runner switch
and config gates in `Tests/Integration/IntegrityValidationConfig.psd1`.
Workflows register created resources immediately and assert ownership before
update, mapping, unmapping, or deletion.
