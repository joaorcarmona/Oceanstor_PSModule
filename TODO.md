# TODO — open, deferred & future work

The open-work tracker for `POSH-Oceanstor`. Completed work, the release-readiness gate,
the full live-validation history, and the **Standing safety reference** live in
[CHANGELOG.md](CHANGELOG.md).

> **Nothing here blocks the `v1.0.0-beta` release.** Every item is either *deferred by
> design* (blocked on an external prerequisite — a second lab array, an undocumented REST
> endpoint, or a maintainer/ops decision) or scheduled for a *future feature cycle*.
>
> Rules before picking anything up: do **not** implement a deferred item until its stated
> re-open trigger is met; **never guess REST bodies** for undocumented endpoints; read the
> "Standing safety reference" in [CHANGELOG.md](CHANGELOG.md) before writing any mutating
> cmdlet.

---

## Deferred by design

Each item is blocked on a stated external prerequisite. Do not implement until the re-open
trigger is met.

### Blocked on hardware / operator input
- **Replication & HyperMetro live mutation** — pair mutation, dual-array NAS, and
  failover/switchover/priority-switch exercises. Need a **second lab array** plus operator-supplied
  `RemoteDeviceId`/`RemoteLunId`/`DomainId`. These stay `SkippedUnsafe` by default and never touch
  pre-existing DR objects.
- **Storage-pool `Set`/create/delete/resize** — persistent, non-reversible pool state; the module
  targets multiple generations (V3 & V6) but the on-branch REST reference covers only Dorado
  6.1.6. Re-open with a per-generation lab array or vendor confirmation; scope any `Set` to
  description/threshold only, never capacity/tier/protection. (Rename is already shipped and
  live-validated — see CHANGELOG.)

### Blocked on undocumented / missing REST endpoints
- **Certificate import / export / remove** — no documented upload endpoint; unquantified
  private-key retrieval risk; no approved lab-safe removal procedure.
- **Bond member add/remove** and **DR batch operations** — no documented REST endpoint.
- **Alarm acknowledge** — the 6.1.6 reference documents no acknowledge/confirm endpoint
  (`confirmTime` is a read-only field only); effectively rejected.
- **Alarm clear — live validation.** `Clear-DMAlarm` ships (`DELETE alarm/currentalarm?sequence=`,
  `ConfirmImpact = 'High'`, clear-by-captured-sequence only). Live validation is blocked because
  **no REST endpoint generates a disposable test alarm** — a full sweep of the 6.1.6 reference
  confirms the only "test" alarm verbs (`alarm_restore/test_alarm_restore_address`,
  `alarm_sms/send_test_sms`) test *notification delivery*, not alarm *creation*. Re-open when a
  feature branch adds a reliable test-alarm generator; never clear pre-existing alarms.

### Research → graduated to feature work
- **LDAP/AD auth, Email/SMTP alerting, password-policy** — authentication/alerting-sensitive;
  research captured in `docs/system-management/ldap-ad-smtp-alerting-research.md`.

---

## Future feature branches

Next-cycle work; each needs its own scoped branch. Not part of this release.

- **Network:** static routes/gateways; iSCSI portal/CHAP; NVMe-oF interface cmdlets; per-port
  performance/stats getters; LLDP neighbor getter; friendly-name enum aliases
  (`-BondPortType HostService`) with numeric back-compat.
- **Replication/HyperMetro:** remote LUN rescan + remote device link management; DR
  dashboards/reporting (pair-health rollups via the report template system).
- **QoS:** `qos-filesystem-live-validation`; `qos-admin-cookbook`.
- **Block storage:** `block-storage-troubleshooting`; `protection-group-live-examples`.
- **File/NAS:** `nas-service-config` (AD/LDAP/CIFS setup); `quota-live-matrix`;
  `nas-troubleshooting-docs`.
- **Snapshots:** `snapshot-policy-research`; `snapshot-restore-runbooks`; `snapshot-copy-cookbook`.
- **System management:** LDAP/AD auth implementation; Email/SMTP alerting implementation;
  alarm/event lifecycle beyond read-only `Get-DMAlarmHistory`.
- **Docs polish (low priority):** relationship diagrams (would introduce mermaid as a new
  convention); Excel-export polish — a **code** task for `Export-DMStorageToExcel` (its inline
  `#TODO`s: SaveFileDialog, MappingView sheet, performance-report chart templates).
