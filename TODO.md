# POSH-Oceanstor TODO

This backlog records confirmed gaps and explicit design decisions still required. Detailed internal object maps remain private and are not stored in Git.

## Correctness

- [x] ~~Add integration checks for actual LUN and file-system capacity expansion.~~ `Set-DMLun -Capacity` and `Set-DMFileSystem -Capacity` are now exercised in the mutation workflows (`Lun.ps1`, `Nas.ps1`), with read-back verification that `RealCapacity` matches the expanded value. A unit test also covers the case where capacity expansion is skipped after a failed property modification.
- [x] ~~Verify Set operations by reading back the changed description/properties, not only the renamed identity.~~ `Set-DMHost`, `Set-DMHostGroup`, `Set-DMLunGroup`, `Set-DMPortGroup`, `Set-DMLun`, and `Set-DMFileSystem` each now re-fetch the object after modification and assert the description text actually persisted, not just that the object still exists.
- [x] ~~Add direct tests for mutation ownership transfer after rename, including cleanup after a read-back or dependent-operation failure.~~ `Tests/Unit/Private/ValidationHelpers.Tests.ps1` directly tests `Update-TestOwnedResourceIdentity` and `Invoke-OwnedRemoval`, including an end-to-end scenario where a read-back failure occurs between a rename and cleanup, confirming cleanup still targets the renamed identity and ownership isn't lost when a removal fails.

## Command coverage decisions

- [ ] Decide whether mapping views need `Set-DMMappingView`, `Rename-DMMappingView`, and a matching object `Rename()` method.
- [ ] Decide whether storage pools need supported Set/Rename commands and object methods; confirm the Huawei API behavior for each supported device generation first.
- [ ] Decide which NAS children need modification commands: dTrees, CIFS shares, NFS shares, and NFS clients currently support only their existing create/read/delete surface.
- [ ] Decide whether initiator objects need action methods or should remain command-only objects.
- [ ] Decide whether network objects (LIFs, VLANs, physical ports, bonds, and vStores) should remain read-only or gain supported mutation commands.

## CI and cross-platform

- [x] ~~Add Ubuntu and macOS to the CI test matrix.~~ Fixed by removing the `Get-DMSystem` call from inside the `OceanstorSession` constructor instead of working around it in test scaffolding. PowerShell class constructors resolve function calls from the session scope rather than the module scope on Linux/macOS, which bypassed the Pester mock inside `OceanstorSession::new()`; `Connect-deviceManager` now resolves `Version` itself after construction, where mocks apply normally. `windows-latest`, `ubuntu-latest`, and `macos-latest` all pass in the Pester matrix.

## Consistency and maintainability

- [x] ~~Expand unit coverage for public commands that had no direct tests.~~ Disconnect-deviceManager, New-DMnfsShare, New-DMnfsClient, and Set-DMdnsServer now have dedicated tests. All 127 public commands are referenced in at least one unit test file.
- [x] ~~Define a consistent minimum object-method surface, such as `Rename()`, `Delete()`, and relationship helpers, for mutable returned objects.~~ `Delete()` added to all 11 mutable classes that lacked it: `OceanstorLunv6`, `OceanstorLunv3` (throws `NotSupportedException`), `OceanStorFileSystem`, `OceanStorHost`, `OceanStorHostGroup`, `OceanStorLunGroup`, `OceanstorPortGroup`, `OceanStorMappingView`, `OceanStorNFSShare`, `OceanStorCIFSShare`, and `OceanstorDtree` (resolves parent file system name from `parentId` before delegating to `Remove-DMDTree`). Each method is unit-tested in the corresponding `Classes.*.Tests.ps1` file.
- [x] ~~Generate command/object inventory during CI and fail when a new public command or class is absent from the maintained coverage metadata.~~ `Tests/ModuleCoverage.psd1` records all 39 class names. `Tests/Unit/Private/ModuleInventory.Tests.ps1` (auto-discovered by `Invoke-UnitTests.ps1`) cross-checks every `Public/*.ps1` file against `FunctionsToExport` in the module manifest, and every `Private/class-*.ps1` file against `ModuleCoverage.psd1`; CI fails if any new command or class is undeclared.
