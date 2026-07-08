# alpha-v1.0.0 Remaining Open TODOs — Index

This is a summary index only. It does not substitute for the detailed phase files below — read the
relevant phase file before acting on any item.

Generated from a fresh repository sweep (2026-07-08) using `tokensave_todos` (129 code-level
markers: 86 TODO, 40 NOTE, 1 WIP, 2 UNIMPLEMENTED) cross-referenced against all seven domain
`docs/*/TODO.md` files, `Oceanstor_PSModule_TODO.md`, `todo/release-readiness-go-no-go.md`, and
`todo/followup-name-loopvar-collision-audit.md`.

## Totals

- **Open/deferred/blocker items found and classified:** 26
- **Stale/dangling documentation references found:** 2 (both instances of the
  `post-merge-phase-06`/`post-merge-phase-08` naming-scheme leftover)
- **Internally contradictory document found:** 1 (`release-readiness-go-no-go.md` — stale `NO-GO`
  header vs. its own inline `GO` update)

## Count by classification

| Classification | Count |
|---|---:|
| Docs-only refresh/cleanup | 4 |
| Code defect (open, unfixed) | 1 |
| Code + tests (low risk) | 1 (loop-var audit, 9 files) |
| Decision-only / ops carry-forward | 2 (CI signing, publishing) |
| Live-validation scheduling (decision-only) | 9 sessions consolidated |
| Safety-critical deferred (indefinite, decision-only) | 9 items |
| Future feature branches (backlog, decision-only) | 18 items across 7 domains |

## Generated phases

| Phase | File | Type | Release-blocking |
|---|---|---|---|
| 01 | [phase-01-release-readiness-refresh.md](alpha-v1.0.0-remaining-open-todos-phase-01-release-readiness-refresh.md) | Docs-only + 1 code defect (fix deferred to later session) | Partly — doc status only, not the defect |
| 02 | [phase-02-ci-signing-publishing-readiness.md](alpha-v1.0.0-remaining-open-todos-phase-02-ci-signing-publishing-readiness.md) | Decision-only | No |
| 03 | [phase-03-loopvar-collision-audit.md](alpha-v1.0.0-remaining-open-todos-phase-03-loopvar-collision-audit.md) | Code + tests | No |
| 04 | [phase-04-live-validation-session-scheduling.md](alpha-v1.0.0-remaining-open-todos-phase-04-live-validation-session-scheduling.md) | Decision-only / scheduling | No |
| 05 | [phase-05-safety-critical-deferred-decisions.md](alpha-v1.0.0-remaining-open-todos-phase-05-safety-critical-deferred-decisions.md) | Decision-only | No |
| 06 | [phase-06-future-feature-branches-backlog.md](alpha-v1.0.0-remaining-open-todos-phase-06-future-feature-branches-backlog.md) | Decision-only | No |
| 07 | [phase-07-documentation-polish-backlog.md](alpha-v1.0.0-remaining-open-todos-phase-07-documentation-polish-backlog.md) | Docs-only | No |

## Items intentionally rejected / deferred (not scheduled for implementation)

- Alarm acknowledge — no documented endpoint (Phase 05).
- Bond member add/remove — no documented REST endpoint (Phase 05).
- DR batch operations — no documented REST endpoint (Phase 05).
- Speculative REST bodies for any undocumented endpoint — rejected as a practice across all
  domains.

## Items considered stale or already completed

- `todo/alpha-v1.0.0-open-issues-phase-01-release-blockers-gate.md` — confirmed `STATUS: COMPLETE
  (2026-07-07)`.
- Network Phase 06/Phase 05 hardening and carry-over — confirmed complete per
  `docs/network/TODO.md` "Recently Completed".
- Replication/HyperMetro Phase 07 — confirmed complete per `docs/replication-hypermetro/TODO.md`
  "Recently Completed".
- SystemManagement SNMP USM analyzer finding — confirmed `RESOLVED (Phase 01, 2026-07-07)`.
- System-management Phase 07 event query (`Get-DMAlarmHistory`) — confirmed implemented
  (2026-07-08).
- Docs Phase 08 polish pass (block/network/QoS, lab-IP sanitization) — confirmed via commit
  `c79921a`.
- The `release-readiness-go-no-go.md` top-level `NO-GO` header — **stale**, contradicted by its own
  inline Phase 01 update (see Phase 01 of this plan).
- Two dangling `post-merge-phase-06`/`post-merge-phase-08` references in
  `Oceanstor_PSModule_TODO.md` and one more in `docs/network/TODO.md` — stale naming-scheme
  leftovers, not real open work (see Phases 01 and 07).

## Release blockers

**None identified.** The hard release gate (0 analyzer errors, all unit tests passing) is already
`GO` per the existing evidence in `release-readiness-go-no-go.md`'s own Phase 01 update — the only
issue is that the document's headline hasn't been refreshed to say so (Phase 01 of this plan fixes
the presentation, not the underlying gate, which was already green).

## Recommended implementation order

1. **Phase 01** — cheap docs refresh + defect investigation kickoff (unblocks accurate release
   status reporting immediately).
2. **Phase 03** — low-risk, self-contained code hygiene fix, no external dependencies.
3. **Phase 07** — docs polish, can run in parallel with Phase 03.
4. **Phase 02** — external action (certificate + flag flips), whenever a maintainer is ready.
5. **Phase 04** — schedule supervised live sessions per the recommended order inside that file,
   as operator time and lab access allow.
6. **Phase 05** — no action; re-visit only when an external blocker changes.
7. **Phase 06** — pull from when planning the next feature cycle.

## Notes

- This index and its phases are planning/documentation artifacts only. No code was implemented, no
  live validation was performed, and no branch operations occurred while generating this plan.
