# POSH-Oceanstor — Deep Analysis Findings

> Generated: 2026-06-30
> Updated: 2026-07-01
> Scope: Security · Correctness / Error Handling · Code Quality
> Status: All tracked findings fixed, closed by design, or validated as not a bug

---

## Table of Contents

1. [Security](#security)
   - [Critical](#security-critical)
   - [Medium / Low](#security-medium--low)
2. [Correctness & Error Handling](#correctness--error-handling)
   - [Critical bugs](#correctness-critical-bugs)
   - [High](#correctness-high)
   - [Medium](#correctness-medium)
3. [Code Quality & Improvements](#code-quality--improvements)
   - [High — silent functional bugs](#quality-high--silent-functional-bugs)
   - [Medium](#quality-medium)
4. [Priority Fix Order](#priority-fix-order)

---

## Security

### Security — Critical

#### S1 · `-SkipCertificateCheck` unconditional

| Field | Value |
|-------|-------|
| **Files** | `POSH-Oceanstor/Private/Invoke-DeviceManager.ps1` · `POSH-Oceanstor/Public/Connect-deviceManager.ps1` |
| **Lines** | `Invoke-DeviceManager.ps1:148,150` · `Connect-deviceManager.ps1:87` |
| **Status** | ✅ Fixed — certificate validation now defaults on; `Connect-deviceManager -SkipCertificateCheck` explicitly opts a session into skipping validation, and `Invoke-DeviceManager` only forwards the switch for those sessions. |

`-SkipCertificateCheck` was previously passed on every `Invoke-RestMethod` call, including the initial login. TLS certificate validation was disabled globally — a man-in-the-middle attacker on the same network could intercept all traffic, including credentials and session tokens. Using HTTPS without certificate validation is equivalent to HTTP.

**Fix:** Added a `-SkipCertificateCheck` switch to `Connect-deviceManager` that defaults to `$false`. The setting is stored on the session object and forwarded by `Invoke-DeviceManager` only when explicitly requested. The module help documents that skipping validation is only appropriate for lab/test environments.

**Tests:** Added unit coverage for the secure default login path, the explicit `-SkipCertificateCheck` login path, persisted session state, and conditional forwarding inside `Invoke-DeviceManager`.

---

#### S2 · SecureString extracted to plaintext and never cleared

| Field | Value |
|-------|-------|
| **File** | `POSH-Oceanstor/Public/Connect-deviceManager.ps1` |
| **Lines** | `77–78`, `80–83`, `96` |
| **Status** | ✅ Fixed — `$username`, `$password` nulled and the `$CredentialsBytes` byte array zeroed with `[Array]::Clear` immediately after the Base64 header and login body are built. `$body` hashtable is also nulled at that point. |

```powershell
$username = $credentials.GetNetworkCredential().UserName   # line 77
$password = $credentials.GetNetworkCredential().Password   # line 78

$body = @{ username = $username; password = $password; scope = 0 }  # line 80
```

`GetNetworkCredential().Password` converts the `SecureString` to a plain `[string]` that is placed in a hashtable and persists in memory for the lifetime of the session. The variable is never zeroed or disposed. A memory dump or debugger attachment can recover credentials.

**Fix:** Clear the plaintext immediately after use: assign `$null` to `$username` and `$password` once the Base64 header and request body have been constructed.

---

#### S3 · Basic Auth credentials kept alive in session headers

| Field | Value |
|-------|-------|
| **File** | `POSH-Oceanstor/Public/Connect-deviceManager.ps1` |
| **Lines** | `96–100` |
| **Status** | ✅ Fixed — commit `34551fd` |

```powershell
$CredentialsBytes   = [System.Text.Encoding]::UTF8.GetBytes("$username:$password")
$EncodedCredentials = [Convert]::ToBase64String($CredentialsBytes)
$SessionHeader.Add("Authorization", "Basic $EncodedCredentials")  # line 100
```

Base64-encoded `username:password` is stored as a plain string in the session header dictionary and sent with **every** subsequent API call. Basic Auth credentials should be used only for login; all further requests should rely on `iBaseToken` alone.

**Fix:** Removed the `Authorization` header from `$SessionHeader` entirely and removed the now-dead `$CredentialsBytes`/`$EncodedCredentials` computation block. `$SessionHeader` now contains only the `iBaseToken` entry. Tests updated to assert `ContainsKey('Authorization') | Should -BeFalse`.

---

#### S4 · User input interpolated into REST paths without URI encoding

| Field | Value |
|-------|-------|
| **Files** | `Get-DMhostbyName.ps1:62` · `Get-DMhostbyId.ps1:62` · `Get-DMlunByWWN.ps1:65` · `Get-DMLunsbyFilter.ps1:75` · `Get-DMAlarm.ps1:87` · `Remove-DMFiberChannelInitiator.ps1:77,79` |
| **Status** | ✅ Fixed |

```powershell
# Get-DMhostbyName.ps1:62
$response = Invoke-DeviceManager ... -Resource "host?filter=NAME:$Name"

# Get-DMLunsbyFilter.ps1:75
$resource = "lun?filter=$($apiField):$Keyword"
```

Values supplied by the caller are interpolated directly into REST query strings. Special characters (colons, ampersands, wildcards) can alter the filter expression sent to the API. `New-DMNamedObjectUpdate.ps1` already demonstrates the correct fix:

```powershell
$resource += "?vstoreId=$([uri]::EscapeDataString($VstoreId))"   # correct pattern
```

**Fix:** Wrap every user-supplied value that goes into a URL with `[uri]::EscapeDataString()`.

---

### Security — Medium / Low

#### S5 · `iBaseToken` stored as plain string (Medium)

| Field | Value |
|-------|-------|
| **File** | `POSH-Oceanstor/Private/class-OceanstorSession.ps1` |
| **Lines** | `22` |
| **Status** | ✅ Partially fixed — redundant copy removed |

```powershell
hidden [string]$iBaseToken
```

`hidden` only suppresses default display formatting — any code can read `$session.iBaseToken` directly. The token is effectively a bearer credential.

**Fix:** Removed the `$this.iBaseToken` field and its constructor assignment — it was written but never read by any production code. The token still lives as a plain string in `$this.Headers["iBaseToken"]` (required for HTTP calls), so this reduces the credential's memory footprint but does not fully eliminate plaintext exposure. Full mitigation would require `SecureString` wrappers around the Headers dict, which would complicate every API call path.

---

#### S6 · `$global:deviceManager` accessible to all code in the session (Medium)

| Field | Value |
|-------|-------|
| **File** | `POSH-Oceanstor/Public/Connect-deviceManager.ps1` |
| **Lines** | `110` |
| **Status** | ✅ Improved — cache narrowed from global to module scope |

Any script or third-party module loaded in the same PowerShell runspace could read `$global:deviceManager` and extract the `iBaseToken` or Auth header.

**Fix:** The cached session moved from `$global:deviceManager` to a module-private `$script:CurrentOceanstorSession` variable (see `POSH-Oceanstor.psm1`), so it's no longer visible via `Get-Variable -Scope Global` or writable by unrelated scripts sharing the runspace. The "connect once and forget" UX is unchanged — `Connect-deviceManager` still caches a session that every other command falls back to automatically when `-WebSession` is omitted, and multi-array use cases are still covered by `-WebSession -PassThru`. This is encapsulation hygiene, not a hard security boundary: any code running in the same process can still reach a module-scoped variable via `& (Get-Module POSH-Oceanstor) { $script:CurrentOceanstorSession }`, so it does not stop a malicious actor with arbitrary code execution in that process. Full elimination of implicit session state (always requiring `-WebSession`) was considered and rejected for the same UX reason as before.

---

#### S7 · Trace redaction regex does not cover `Authorization` header (Low)

| Field | Value |
|-------|-------|
| **File** | `POSH-Oceanstor/Private/Invoke-DeviceManager.ps1` |
| **Lines** | `1–38` |
| **Status** | ✅ Closed — superseded by S3. The module no longer stores or forwards the Basic `Authorization` header after login, and trace capture does not persist request headers on normal API calls. Existing password/token/secret redaction remains in place for request and response bodies. |

The `Copy-DMTraceValue` redaction function masks keys matching `(?i)(password|passwd|pwd|token|secret)` but will not redact the `Authorization` key (containing Base64-encoded credentials) that is always present in the request headers.

**Resolution:** The premise was removed by the S3 fix: Basic Auth credentials are no longer kept in `$SessionHeader` after login. There is no long-lived `Authorization` header for `Invoke-DeviceManager` trace output to redact.

---

## Correctness & Error Handling

### Correctness — Critical Bugs

#### C1 · `@(...)[0]` null-dereference pattern in 60+ commands

| Field | Value |
|-------|-------|
| **Representative files** | `Remove-DMLun.ps1:90` · `Remove-DMFileSystem.ps1:95` · `Add-DMLunToLunGroup.ps1:158` · `Remove-DMLunSnapShot.ps1:89` · and ~55 more |
| **Status** | ✅ Fixed |

```powershell
$lun = @(Get-DMlun -WebSession $session | Where-Object Name -CEQ $LunName)[0]
$resource = "lun/$($lun.Id)"   # $lun.Id is $null if filter returns nothing
```

If `Where-Object` returns zero results (race condition, case mismatch, deleted object), `[0]` returns `$null`. Every property access on `$null` silently returns `$null`, which is then sent to the API as an empty or malformed resource path. The ValidateScript that runs during parameter binding calls `Get-DMlun` independently — the object may be removed between validation and execution.

**Applied fix:** Added an explicit null-check guard immediately after every `$var = @(...)[0]` dereference across 51 Public/*.ps1 files (70 insertion points total). A clear `throw` now fires before any property access reaches the API, rather than silently sending a malformed path.

```powershell
$lun = @(Get-DMlun -WebSession $session | Where-Object Name -EQ $LunName)[0]
if ($null -eq $lun) { throw "Could not resolve 'lun' — the object may have been removed since parameter validation." }
```

---

#### C2 · `OceanstorLunv6.Rename()` never updates `$this.Name`

| Field | Value |
|-------|-------|
| **File** | `POSH-Oceanstor/Private/class-OceanstorLunv6.ps1` |
| **Lines** | `376–383` |
| **Status** | ✅ Fixed — `$result[0].Code` instead of `$result.Code` |

```powershell
[psobject] Rename([string]$NewName) {
    $result = Rename-DMLun ... -Confirm:$false   # returns List[object]
    if ($result.Code -eq 0) {                    # List has no .Code property → $null
        $this.Name = $NewName                    # never executes
    }
    return $result
}
```

`Rename-DMLun` (which delegates to `Set-DMLun`) returns a `List[object]`. Accessing `.Code` on a `List` returns `$null`, so `$null -eq 0` is always `$false`. `$this.Name` is never updated after a successful rename — any subsequent method call on the same object uses the stale name.

**Fix:**
```powershell
if ($result[0].Code -eq 0) { $this.Name = $NewName }
```

The same logic issue likely exists in `OceanstorLunv3.Rename()` and should be verified.

---

#### C3 · Inverted WorkloadType logic in `OceanstorLunv6`

| Field | Value |
|-------|-------|
| **File** | `POSH-Oceanstor/Private/class-OceanstorLunv6.ps1` |
| **Lines** | `246–249` |
| **Status** | ✅ Fixed |

```powershell
if ($lunReceived.WORKLOADTYPEID) {
    $this.{Workload Type Name} = "invalid"      # set when ID is present (wrong)
} else {
    $this.{Workload Type Name} = $lunReceived.WORKLOADTYPENAME   # set when ID is absent (wrong)
}
```

The condition is inverted. Every LUN that has a workload type assigned gets `"invalid"` as its name; every LUN without a workload type has its type name read from an empty/null field.

**Fix:** Swap the branches:
```powershell
if ($lunReceived.WORKLOADTYPEID) {
    $this.{Workload Type Name} = $lunReceived.WORKLOADTYPENAME
} else {
    $this.{Workload Type Name} = $null
}
```

---

### Correctness — High

#### C4 · No meaningful error when `$deviceManager` is null

| Field | Value |
|-------|-------|
| **Files** | All ~100 public commands |
| **Status** | ✅ Fixed — guard added inside `Invoke-DeviceManager.ps1` itself (single chokepoint every command funnels through), so all ~100 commands get the clear error without per-command changes. |

When `$script:CurrentOceanstorSession` is `$null` and no `-WebSession` is provided, commands fall through to `Invoke-DeviceManager` which fails with a generic null-property PowerShell error rather than "Please call Connect-deviceManager first." A simple guard at the top of each command (or inside `Invoke-DeviceManager`) would give a clear diagnostic.

---

#### C5 · `Select-Object -ExpandProperty data` before checking `error.Code`

| Field | Value |
|-------|-------|
| **Files** | `Get-DMlun.ps1:59`, `Get-DMFileSystem.ps1:57`, `Get-DMhost.ps1:57`, and most other `Get-DM*` commands |
| **Status** | ✅ Fixed |

```powershell
$response = Invoke-DeviceManager ... | Select-Object -ExpandProperty data
```

If the API returns a non-zero error code (e.g. session expired, permission denied), `$response.data` may not exist. `-ExpandProperty data` throws `"Cannot expand property 'data'"` instead of surfacing the API error description.

**Applied fix:** Added private helper `Select-DMResponseData` (pipeline-compatible) that checks `error.Code` before returning `.data` and throws a descriptive error on non-zero codes. Replaced all 38 occurrences of `| Select-Object -ExpandProperty data` in Public commands with `| Select-DMResponseData`. All 10 affected test modules updated to dot-source the helper.

---

#### C6 · Second `Connect-deviceManager` call leaks the prior array session

| Field | Value |
|-------|-------|
| **File** | `POSH-Oceanstor/Public/Connect-deviceManager.ps1` |
| **Lines** | `110` |
| **Status** | ✅ Fixed — `Disconnect-deviceManager` is now called on the prior cached session (best-effort, wrapped in try/catch with `Write-Warning` on failure) immediately before it is overwritten. A failed disconnect (e.g. the old session already expired) never blocks the new connection from being established. |

`$script:CurrentOceanstorSession = $connection` overwrites the existing session object without calling `Disconnect-deviceManager` first. The previous authenticated session remains open on the array indefinitely, consuming a connection slot.

---

### Correctness — Medium

#### C7 · `Remove-DMLun` skips pre-flight mapping check (Medium)

| Field | Value |
|-------|-------|
| **File** | `POSH-Oceanstor/Public/Remove-DMLun.ps1` |
| **Lines** | `103–105` |
| **Status** | ✅ Fixed |

The LUN object carries an `'is Mapped'` property. A deletion attempt on a mapped LUN will fail with a generic API error. Checking this before the delete would give a user-readable message.

**Fix:** Added a pre-flight check after the LUN is resolved — if `$lun.'is Mapped' -eq 'mapped'`, a clear error is thrown before `ShouldProcess` and the API is never called. New `Remove-DMLun.Tests.ps1` covers the mapped-LUN guard, WhatIf, ImmediateDelete, VstoreId, and name-validation paths.

---

#### C8 · Redundant triple API call in host/group membership commands (Medium)

| Field | Value |
|-------|-------|
| **Files** | `Add-DMHostToHostGroup.ps1:53,71,115` · `Add-DMPortToPortGroup.ps1:126` · `Remove-DMHostFromHostGroup.ps1:115` |
| **Status** | ✅ Fixed |

`Get-DMhost` is called once in `ValidateScript`, once in `ArgumentCompleter`, and once in the function body — three API round-trips for a single command invocation. For large environments (hundreds of hosts), this is measurably slow.

**Fix:** `ValidateScript` now stores its resolved list in a `$script:` cache variable (e.g. `$script:_dmAddHostHosts`). The function body reads from the cache instead of calling the API again, reducing host/group lookups from three round-trips to one. The `ArgumentCompleter` path (tab completion only) is unaffected. New test files for all three commands include `Should -Invoke … -Times 1 -Exactly` assertions that enforce the single-call guarantee.

---

#### C9 · Fragile JSON fallback in `Get-DMlunbyLunGroup` (Medium)

| Field | Value |
|-------|-------|
| **File** | `POSH-Oceanstor/Public/Get-DMlunbyLunGroup.ps1` |
| **Lines** | `70–82` |
| **Status** | ✅ Fixed |

When `$associatedLunIdList` is a string that fails `ConvertFrom-Json`, the fallback is a naive comma-split. If the string is `"[1,2,3]"` (a JSON array representation), the split produces `"[1"`, `"2"`, `"3]"` — stripped to `"1"`, `"2"`, `"3"` by the trim/strip step, which works by accident. Any other format change would silently produce wrong IDs.

**Fix:** The catch block now explicitly strips surrounding `[` and `]` before splitting, so both `"[1,2,3]"` and `"1,2,3"` produce the same clean ID list deterministically. Tests cover the native array, JSON string, bracket-fallback, CSV-fallback, null, and missing-data cases.

---

## Code Quality & Improvements

### Quality — High · Silent Functional Bugs

#### Q1 · `New-DMFileSystem`: all optional parameters share `Position = 0`

| Field | Value |
|-------|-------|
| **File** | `POSH-Oceanstor/Public/New-DMFileSystem.ps1` |
| **Lines** | `101–167` |
| **Status** | ✅ Fixed — WebSession=0, FileSystemName=1, StoragePoolID=2; Position removed from all optional params |

Multiple parameters declare `Position = 0`. PowerShell only honours one parameter per position per parameter set — subsequent definitions at the same position are silently unreachable by positional binding. Users must use named parameters for every argument.

**Fix:** Assign unique sequential positions as `New-DMLun.ps1` does correctly.

---

#### Q2 · `New-DMHost` and `New-DMHostGroup` accept `-VstoreId` but ignore it

| Field | Value |
|-------|-------|
| **Files** | `POSH-Oceanstor/Public/New-DMHost.ps1:89–93` · `POSH-Oceanstor/Public/New-DMHostGroup.ps1` |
| **Status** | ✅ Not a bug — already implemented correctly. Both files add `$body.vstoreId = $VstoreId` when VstoreId is provided (New-DMHost.ps1:91–93, New-DMHostGroup.ps1:67–69). Analysis agent was incorrect. |

---

#### Q3 · `Set-DMHost`, `Set-DMHostGroup`, `Set-DMLunGroup`: VstoreId not forwarded to inner `Get-` call

| Field | Value |
|-------|-------|
| **Files** | `POSH-Oceanstor/Public/Set-DMHost.ps1:53` · `Set-DMHostGroup.ps1:53` · `Set-DMLunGroup.ps1:53` |
| **Status** | ✅ Fixed |

These commands accept `-VstoreId` and pass it to `New-DMNamedObjectUpdate` (for the PUT call) but do **not** forward it to the inner `Get-DMhost` / `Get-DMhostGroup` / `Get-DMlunGroup` call. The lookup searches across all vStores, which may match an object in the wrong vStore and modify it.

**Contrast:** `Set-DMPortGroup.ps1` correctly passes `VstoreId` to `Get-DMPortGroup`.

**Fix:** Added `-VstoreId` parameter to `Get-DMhost`, `Get-DMhostGroup`, and `Get-DMlunGroup` (appends `?vstoreId=X` to the resource URL when supplied, matching the `Get-DMPortGroup` pattern). Updated `Set-DMHost`, `Set-DMHostGroup`, and `Set-DMLunGroup` to forward `-VstoreId $VstoreId` to their inner getter calls. New test files for all three getters verify the resource URL with and without VstoreId.

---

### Quality — Medium

#### Q4 · `New-DMLun` and `New-DMFileSystem` duplicate `ConvertTo-DMCapacityBlock` inline

| Field | Value |
|-------|-------|
| **Files** | `POSH-Oceanstor/Public/New-DMLun.ps1:184–227` · `POSH-Oceanstor/Public/New-DMFileSystem.ps1:221–269` |
| **Status** | ✅ Fixed |

Both commands contain full manual capacity-parsing logic instead of calling the existing `ConvertTo-DMCapacityBlock` private helper (which `Set-DMLun` and `Set-DMFileSystem` use correctly). This creates a maintenance split: a bug fix or unit addition must be applied in three places.

An additional inconsistency: a bare integer passed to `New-DMLun -Capacity 1024` means 1024 blocks (512-byte); the same value to `New-DMFileSystem -Capacity 1024` means 1024 GB. This is controlled by the `UnitlessUnit` argument to the helper but is invisible to the caller.

**Fix:** Replaced the ~40-line inline parsing blocks in both commands with `ConvertTo-DMCapacityBlock -Capacity $capacity -UnitlessUnit Blocks` (New-DMLun) and `-UnitlessUnit GB` (New-DMFileSystem), matching how `Set-DMLun` and `Set-DMFileSystem` already call the helper. Both test modules updated to dot-source `ConvertTo-DMCapacityBlock.ps1`; all existing capacity tests pass unchanged.

---

#### Q5 · `Set-DMLun` return type differs from all other `Set-DM*` commands

| Field | Value |
|-------|-------|
| **File** | `POSH-Oceanstor/Public/Set-DMLun.ps1:140,156` |
| **Status** | ✅ Fixed |

`Set-DMLun` returns `List[object]` (one error object per operation — property change and/or expand). Every other `Set-DM*` command returns a single `PSCustomObject` (`$response.error`). Callers need different code paths for `Set-DMLun` vs the rest.

**Applied fix:** Replaced the `List[object]` accumulator with a single `return $response.error` path. If only property changes are requested, their error is returned. If both property and capacity changes are requested and the property update succeeds, the capacity-expansion error is returned (the relevant result at that point). If the property update fails, its error is returned immediately — matching the early-exit behaviour every other `Set-DM*` command has.

---

#### Q6 · `Set-DMdnsServer` return type inconsistency

| Field | Value |
|-------|-------|
| **File** | `POSH-Oceanstor/Public/Set-DMdnsServer.ps1:63–70` |
| **Status** | ✅ Fixed — now returns `$response.error`, matching every other `Set-DM*` command. The unconditional `Get-DMdnsServer` read-back call on success was also removed (it was an unnecessary extra round trip). |

Returns a `Hashtable` on success and a `[string]` on error, unlike all other Set-DM* commands which return `$response.error`. Callers must check `if ($result -is [hashtable])` instead of checking `.Code`.

---

#### Q7 · `Get-DMdnsServer` fragile string parsing

| Field | Value |
|-------|-------|
| **File** | `POSH-Oceanstor/Public/Get-DMdnsServer.ps1:47–61` |
| **Status** | ✅ Fixed — replaced manual bracket-stripping/comma-split with `ConvertFrom-Json`. Falls back to wrapping the value in `@()` if the API ever returns an already-deserialized array instead of a JSON string. |

Parses the DNS address list by manually stripping leading/trailing brackets and splitting on commas — a brittle approach that will break on any API response format variation (extra whitespace, empty list, single address without brackets).

---

#### Q8 · `Rename-DMLun` does not document the V6-only restriction

| Field | Value |
|-------|-------|
| **File** | `POSH-Oceanstor/Public/Rename-DMLun.ps1` |
| **Status** | ✅ Fixed — `Rename-DMLun` help now states that it renames OceanStor Dorado V6 LUNs through `Set-DMLun`, making the V6-only restriction visible at the public command entry point. |

The V6 session restriction is enforced inside `Set-DMLun` (which `Rename-DMLun` delegates to) but is not mentioned in `Rename-DMLun`'s own `.SYNOPSIS` or `.DESCRIPTION`. Users on V3/V5 arrays get an error from an inner function without a clear pointer to the cause.

---

## Priority Fix Order

| Priority | ID | Short description | Category | Status |
|----------|----|-------------------|----------|--------|
| 1 | C2 | `Rename()` never updates `$this.Name` — comparing `.Code` on a `List` | Bug | ✅ Fixed |
| 2 | C3 | Inverted WorkloadType logic sets `"invalid"` on every typed LUN | Bug | ✅ Fixed |
| 3 | Q2 | `New-DMHost`/`New-DMHostGroup` silently drop `-VstoreId` | Bug | ✅ Not a bug — already correct |
| 4 | Q3 | `Set-DMHost`/`Set-DMHostGroup`/`Set-DMLunGroup` scope leak across vStores | Bug | ✅ Fixed |
| 5 | Q1 | `New-DMFileSystem` broken positional parameters | Bug | ✅ Fixed |
| 6 | C1 | `@(...)[0]` null-dereference in 60+ commands | Reliability | ✅ Fixed |
| 7 | S1 | `-SkipCertificateCheck` unconditional — make opt-in | Security | ✅ Fixed |
| 8 | S4 | URI injection via unescaped user input in 6+ commands | Security | ✅ Fixed |
| 9 | S2 | Plaintext password variable never cleared | Security | ✅ Fixed |
| 10 | S3 | Basic Auth header kept for entire session lifetime | Security | ✅ Fixed |
| — | S5 | Redundant plaintext iBaseToken field on OceanstorSession | Security | ✅ Partially fixed — redundant copy removed; token still in Headers (required) |
| — | S6 | `$global:deviceManager` accessible to all code in the session | Security | ✅ Improved — cache narrowed to module-scoped `$script:CurrentOceanstorSession` |
| 11 | C4 | No helpful error when `$deviceManager` is null | UX | ✅ Fixed |
| 12 | C5 | `Select-Object -ExpandProperty data` before checking error code | Reliability | ✅ Fixed |
| 13 | C6 | Second `Connect-deviceManager` leaks old session on array | Resource | ✅ Fixed |
| 14 | Q4 | `New-DMLun`/`New-DMFileSystem` duplicate capacity parsing | Maintenance | ✅ Fixed |
| 15 | Q5 | `Set-DMLun` returns `List` vs single object in all others | API design | ✅ Fixed |
| 16 | Q6 | `Set-DMdnsServer` inconsistent return type | API design | ✅ Fixed |
| 17 | Q7 | `Get-DMdnsServer` fragile string parsing | Reliability | ✅ Fixed |
| 18 | C7 | `Remove-DMLun` no pre-flight mapping check | UX | ✅ Fixed |
| 19 | C8 | Triple redundant API calls in membership commands | Performance | ✅ Fixed |
| 20 | C9 | Fragile JSON fallback in `Get-DMlunbyLunGroup` | Reliability | ✅ Fixed |
| — | Q9 | `Get-DMlun`, `Get-DMFileSystem`, `Get-DMLunSnapshot`, `Get-DMFileSystemSnapshot` silently truncate at 100 objects | Reliability | ✅ Fixed — `Invoke-DMPagedRequest` pages through all results where the array supports `range`; if an older/variant endpoint rejects `range` with `50331651`, it falls back to the unpaged resource instead of failing the getter. File-system snapshot lookup also supports direct composite-ID reads for arrays where parent listing/filtering is unreliable. |
