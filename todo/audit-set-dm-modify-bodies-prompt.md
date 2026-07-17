# Reusable session prompt — Audit `Set-DM*` cmdlets for missing-mandatory-field modify bodies

> Paste the block below into a fresh Claude Code session in this repo to continue the follow-up
> identified after Phase 1 (commit `aa3c9b3`, branch `alpha2-v1.0.0`). Static analysis only — no
> live hardware runs.

---

## Task

Audit every `Set-DM*` (and any other REST `PUT`/modify) cmdlet in the POSH-Oceanstor module for
the **missing-mandatory-body-field latent bug** — the same defect fixed in Phase 1 for
`Set-DMSnmpTrapServer` and `Set-DMvLan`.

## Background (the contract)

OceanStor Dorado REST `PUT` modify interfaces reject payloads with error **`50331651`**
("The entered parameter is incorrect") or time out with **`1077949001`** when a **Mandatory**
body field is omitted — most commonly `ID`, which must be echoed *in the body*, not just the URL
path. The doc's terse *example* body is NOT the contract; the **Parameters table** is. See memory
`project_oceanstor_modify_body_contract`.

Already fixed (do not re-fix, use as the reference pattern):
- `Set-DMSnmpTrapServer` — read-modify-write via `Get-DMSnmpTrapServer`, re-supplies
  `ID` + `CMO_TRAP_SERVER_IP` + `CMO_TRAP_SERVER_PORT`.
- `Set-DMvLan` — echoes `ID` + `MTU` (both Mandatory per REST §4.6.9.3.8).

## How to work

1. Start with tokensave (NOT Explore agents). Enumerate candidates:
   `tokensave_search` / `tokensave_context` for `Set-DM*` cmdlets and their request bodies;
   grep the `Public/` folder for `Invoke-*` PUT calls and inline `@{ ... }` body hashtables.
2. For each modify cmdlet, cross-check its request body against the interface's **Parameters
   table** in `docs/.../OceanStor Dorado 6.1.6 REST Interface Reference.md` (find the matching
   §). Flag any cmdlet whose body omits a field the table marks **Mandatory** (especially `ID`).
3. Classify each finding: (a) clearly missing a Mandatory field → fix; (b) preserves other
   fields and needs a read-modify-write → note the required `Get-DM*` read-back; (c) no doc /
   undocumented endpoint → do NOT guess a body; record as "needs live capture (Phase 2)".
4. For real fixes: minimal change (echo the Mandatory field / add read-modify-write), add or
   extend the Pester unit test asserting the body contains every Mandatory field, mirror the
   Phase 1 test style (`Set-DMvLan.Tests.ps1`).
5. Use RTK (`& "C:\tools\rtk\rtk.exe" ...`) for `git status`/`diff`/test output.

## Constraints (unchanged)

- Static analysis + unit tests only. **No live array runs** — those are Phase 2, need hardware
  + explicit user confirmation. Never guess REST bodies for undocumented endpoints.
- HyperMetro/Replication DR gates in `Tests/Integration/IntegrityValidationConfig.psd1` must stay
  `$false` in committed config.
- Do NOT commit unless the user explicitly asks. After any approved commit, run `tokensave sync`.

## Deliverable

A table of every modify cmdlet: `cmdlet | endpoint (§) | Mandatory fields per table | fields
currently sent | verdict (OK / fix / needs-live-capture)`. Then, for confirmed fixes only,
propose the minimal code + test diff for review before writing.
