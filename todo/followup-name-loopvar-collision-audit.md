# Follow-up — `$name` Loop-Variable Collision Audit (validated-`$Name` cmdlets)

**Type:** Code + Tests. **Live validation:** not required to reproduce (unit-reproducible).
**Release-blocking:** NO. **Raised:** 2026-07-08, out of the `New-DMQosPolicy` live QoS failure.

## Purpose

Audit and fix any cmdlet that iterates with `foreach ($name in ...)` **inside a function whose
`$Name` (or other validated) parameter carries a `[Validate*]` attribute**. PowerShell variable
names are case-insensitive, so `$name` and `$Name` are the same variable: the loop re-assigns the
validated parameter and re-triggers its attribute on a value that was never meant to satisfy it.

## Root cause (already fixed for QoS)

`New-DMQosPolicy` resolved LUN/FS names with `foreach ($name in $LunName)`. `$Name` is the policy
name parameter (`[ValidateLength(1, 31)][ValidatePattern('^[A-Za-z0-9_.-]+$')]`). When the
integration harness renamed its test LUN to a 39-char name, assigning it into the loop variable
threw *"The variable cannot be validated because the value ... is not a valid value for the Name
variable"* — before any REST call. Fixed by renaming the loop variables to `$lunNameToResolve` /
`$fsNameToResolve` and adding a 39-char regression test (`Tests/Unit/Public/Qos-actions.Tests.ps1`).

## Remaining candidates to audit

Getters using `foreach ($name in $_)` over pipeline input (found 2026-07-08). These iterate `$_`,
not a validated `$Name`, so they are **lower risk** — confirm each cmdlet's `$Name`-style parameter
either does not exist or has no `[Validate*]` attribute that the piped value could violate. If clean,
close this item; if any bind a validated parameter, rename the loop variable.

- `POSH-Oceanstor/Public/Get-DMControllerPerformance.ps1:59`
- `POSH-Oceanstor/Public/Get-DMDiskPerformance.ps1:56`
- `POSH-Oceanstor/Public/Get-DMHostPerformance.ps1:56`
- `POSH-Oceanstor/Public/Get-DMFileSystemPerformance.ps1:56`
- `POSH-Oceanstor/Public/Get-DMLunPerformance.ps1:56`
- `POSH-Oceanstor/Public/Get-DMPerformance.ps1:85`
- `POSH-Oceanstor/Public/Get-DMPortPerformance.ps1:71`
- `POSH-Oceanstor/Public/Get-DMStoragePoolPerformance.ps1:56`
- `POSH-Oceanstor/Public/Get-DMSystemPerformance.ps1:47`

## How to reproduce / detect

A validated parameter is safe to reassign only to a value that still passes its attributes. To find
every colliding site across the module:

```powershell
# loop vars that shadow a validated $Name-style parameter
Select-String -Path .\POSH-Oceanstor\Public\*.ps1 -Pattern 'foreach\s*\(\s*\$name\s+in'
```

For each hit, open the `param()` block: if a same-named parameter (case-insensitive) has any
`[Validate*]` attribute, the loop can throw on otherwise-valid input. Prefer a purpose-named loop
variable (`$lunNameToResolve`, `$fsNameToResolve`, `$perfObjectName`, ...).

## Acceptance

- No `Public/*.ps1` cmdlet reuses a validated parameter name as a loop variable.
- Any fixed cmdlet gains a unit test that passes an input value which would violate the parameter's
  attribute if the collision were present (mirrors the 39-char LUN-name QoS regression test).
