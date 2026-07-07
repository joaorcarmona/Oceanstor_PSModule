# alpha-v1.0.0 Open Issues Phase 08 — Documentation Polish and Post-Live-Run Refresh

**Type:** Docs-only. **Live validation:** none (this phase must not connect to any array).
**Release-blocking:** NO.

## Purpose

Absorb the remaining low-priority documentation polish that Phase 10/11 deliberately left out, and
the doc items that are explicitly gated on live-run evidence (worked runbooks, captured-output
refresh). Phase 11's docs safety sweep already confirmed no real lab IPs and no raw validation/
gap-analysis reports under `docs/`; this phase is polish, not remediation.

## Source TODOs / evidence

- `docs/replication-hypermetro/TODO.md` Documentation — refresh topic-page examples with real
  captured output **once the lab mutation workflows have run**; add a worked "planned failover
  runbook" (split → switch → resync) **after live switchover validation**.
- `docs/block-storage/TODO.md` — deeper mapped-LUN-removal troubleshooting; legacy-wrapper migration
  note (`Get-DMlunByName`/`Get-DMlunByWWN`/`Get-DMhostbyHostGroup`); relationship diagrams; sample
  `Select-Object` inventory views.
- `docs/network/TODO.md` Low Priority — friendly-name parameters doc, decode more display fields.
- `docs/qos/TODO.md` — keep testing status descriptions aligned with `NotConfigured`/`Blocked`.
- General: keep domain README tables in sync with actual files; keep TODO files reflecting shipped
  state.

## Current repository evidence

- Phase 11 docs sweep: no `10.10.10.24` in `docs/`/`README.md`; no `*validation*`/`*gap-analysis*`
  filenames under `docs/`.
- RELEASE_NOTES already retitled to `v1.0.0-alpha1` with finalized gate numbers and a Known Gaps
  section — no release-notes remediation needed, only forward maintenance.
- Several DR/network topic pages carry "captured output pending live run" style gaps.

## Scope

- Add the block-storage docs polish items (troubleshooting page, migration note, diagrams, sample
  views).
- Add friendly-name parameter documentation and decoded display-field notes for network types.
- Keep QoS/testing status descriptions aligned with harness labels.
- After Phase 03/06 live runs complete, refresh DR topic pages with captured output and add the
  planned-failover runbook (this part is **gated on those runs** and may remain pending).

## Out of scope

- Any code, test, or CI change. Any live array access.
- Re-litigating already-correct "not implemented" statements (they are accurate gaps, keep them).
- Release notes content changes beyond ordinary forward maintenance.

## Implementation tasks

1. Block-storage: write the mapped-LUN-removal troubleshooting page; add the legacy-wrapper migration
   note; add relationship diagrams and sample `Select-Object` views.
2. Network: document friendly-name parameters and decoded display fields (align with any params added
   in Phase 05).
3. QoS/testing: verify status-label wording matches `NotConfigured`/`SkippedUnsafe`/`Blocked`/
   `NotRequested` semantics in `Tests/README.md`.
4. DR (gated): once live runs exist, refresh captured-output examples and add the failover runbook.

## Files likely to inspect

- `docs/block-storage/*.md`, `docs/network/*.md`, `docs/qos/*.md`,
  `docs/replication-hypermetro/*.md`, `Tests/README.md`, each domain `README.md`

## Files likely to modify

- The above `docs/**` pages and any out-of-sync domain README tables. **No code, no tests, no CI.**

## Safety considerations

- Docs-only. Use sanitized examples only — never a real lab IP:

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
```

- Never paste real captured output that contains lab IPs, serial numbers, or credentials — sanitize
  before committing.

## Testing strategy

- No unit tests. Verify links resolve and README tables match the actual file set.

## Verification commands

```powershell
Get-ChildItem docs -Recurse -Filter *.md | Measure-Object   # sanity: file set
Select-String -Path .\docs -Recurse -Pattern '10\.10\.10\.24'   # expect no matches
```

## Dependencies

- The DR captured-output/runbook items depend on Phase 03 (SAN pair) and Phase 06 (dual-array /
  switchover) live runs; they stay pending until those runs produce sanitizable evidence.

## Completion criteria

- Block/network/QoS polish items landed and links/tables in sync.
- No real lab IP or sensitive data anywhere under `docs/`.
- DR captured-output refresh + failover runbook completed once live evidence exists (or explicitly
  left pending with the dependency noted).

## Risks / notes

- Main risk is leaking lab data when refreshing "real captured output" — sanitize every example.
