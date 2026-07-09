# Follow-up — `$name` Loop-Variable Collision Audit

**Status:** COMPLETE (2026-07-09)
**Type:** Defensive internal rename (low risk). No behavior change.

## Background

PowerShell variable names are case-insensitive, so a `foreach ($name in ...)`
loop variable shares the same slot as a `[Validate*]`-attributed `$Name`
parameter. This footgun was fixed once in `New-DMQosPolicy`; the performance
getters carried the same `foreach ($name in $_)` pattern inside the `$Metric`
parameter `ValidateScript` block.

None of these getters currently expose a validated `$Name` parameter, so no
active collision existed — this is a preventive normalization against a future
`-Name` parameter being added.

## Resolution

All occurrences of the loop/local variable `$name` (each holding a performance
metric name) were renamed to `$metricName`. This is a pure internal rename:
public parameters, REST endpoints, request/response shapes, and output classes
are unchanged.

## Per-file result — all 9 candidates fixed

| File | Result |
|------|--------|
| `Public/Get-DMControllerPerformance.ps1`  | fixed — `ValidateScript` foreach renamed |
| `Public/Get-DMDiskPerformance.ps1`        | fixed — `ValidateScript` foreach renamed |
| `Public/Get-DMHostPerformance.ps1`        | fixed — `ValidateScript` foreach renamed |
| `Public/Get-DMFileSystemPerformance.ps1`  | fixed — `ValidateScript` foreach renamed |
| `Public/Get-DMLunPerformance.ps1`         | fixed — `ValidateScript` foreach renamed |
| `Public/Get-DMPerformance.ps1`            | fixed — `ValidateScript` foreach + `end`-block `for` loop local both renamed |
| `Public/Get-DMPortPerformance.ps1`        | fixed — `ValidateScript` foreach renamed |
| `Public/Get-DMStoragePoolPerformance.ps1` | fixed — `ValidateScript` foreach renamed |
| `Public/Get-DMSystemPerformance.ps1`      | fixed — `ValidateScript` foreach renamed |

## Verification

- `Select-String ... 'foreach\s*\(\s*\$name\s+in'` over `Get-DM*Performance.ps1` → no matches remain.
- No bare `$name` token remains in any of the 9 files.
- Targeted Pester (`*Performance*` getters): 57 passed / 0 failed, incl. the
  "rejects unknown metric name" cases that exercise the renamed `ValidateScript`.

No remaining work. Audit closed.
