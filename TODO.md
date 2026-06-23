# POSH-Oceanstor TODO

This backlog records confirmed gaps and explicit design decisions still required. Detailed internal object maps remain private and are not stored in Git.

## Correctness

- [ ] Add integration checks for actual LUN and file-system capacity expansion. Current Set workflows validate description changes and renaming, but do not exercise their capacity parameters.
- [ ] Verify Set operations by reading back the changed description/properties, not only the renamed identity.
- [ ] Add direct tests for mutation ownership transfer after rename, including cleanup after a read-back or dependent-operation failure.

## Command coverage decisions

- [ ] Decide whether mapping views need `Set-DMMappingView`, `Rename-DMMappingView`, and a matching object `Rename()` method.
- [ ] Decide whether storage pools need supported Set/Rename commands and object methods; confirm the Huawei API behavior for each supported device generation first.
- [ ] Decide which NAS children need modification commands: dTrees, CIFS shares, NFS shares, and NFS clients currently support only their existing create/read/delete surface.
- [ ] Decide whether initiator objects need action methods or should remain command-only objects.
- [ ] Decide whether network objects (LIFs, VLANs, physical ports, bonds, and vStores) should remain read-only or gain supported mutation commands.

## CI and cross-platform

- [ ] Add Ubuntu and macOS to the CI test matrix. PowerShell class constructors resolve functions from the session scope on Linux rather than the module scope, causing Pester mocks to be bypassed inside `OceanstorSession::new()`. The `Connect-deviceManager.Tests.ps1` test needs refactoring so the class constructor works reliably with mocks on all platforms.

## Consistency and maintainability

- [x] ~~Expand unit coverage for public commands that had no direct tests.~~ Disconnect-deviceManager, New-DMnfsShare, New-DMnfsClient, and Set-DMdnsServer now have dedicated tests. All 127 public commands are referenced in at least one unit test file.
- [ ] Define a consistent minimum object-method surface, such as `Rename()`, `Delete()`, and relationship helpers, for mutable returned objects.
- [ ] Generate command/object inventory during CI and fail when a new public command or class is absent from the maintained coverage metadata.
