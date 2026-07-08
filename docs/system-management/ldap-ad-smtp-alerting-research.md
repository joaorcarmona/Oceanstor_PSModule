# LDAP/AD, Email/SMTP, and Password/Security-Policy Research

**Status:** Research / scoping only. **No implementation is included in Phase 07.**
All three areas below are mutation-heavy management surfaces and remain `open`
future feature branches until a reviewed design exists. This note records the
documented endpoints, blast radius, proposed cmdlet shapes, safety posture, and
open decisions so a future dedicated phase can start from evidence rather than
re-research.

## Source

- `OceanStor Dorado 6.1.6 REST Interface Reference.md` (local copy).
- Cross-referenced with `docs/system-management/TODO.md` Medium-Priority /
  Future-Feature-Branches entries.

## Scope of this note

| Area | Sensitivity | Phase 07 status |
| --- | --- | --- |
| LDAP/AD / domain authentication | Auth-sensitive (High) | Research only — not implemented |
| Email/SMTP alert notification | Alerting-sensitive (Medium/High) | Research only — not implemented |
| Local login password / security policy | Security-sensitive (High) | Research only — not implemented |

---

## 1. LDAP/AD / domain authentication

### Documented endpoints found

| Operation | Method | Resource | Reference section |
| --- | --- | --- | --- |
| Query AD domain settings | GET | (AD domain settings) | 4.1.5.3.1 |
| Query LDAP domain settings | GET | `LDAPConfig` | 4.1.5.3.5 |
| Query LDAP advanced settings | GET | (LDAP advanced) | 4.1.5.3.2 |
| Query LDAP/NIS group / user info | GET | (LDAP group/user) | 4.1.5.3.6 / 4.1.5.3.7 |
| Modify AD domain settings | PUT | (AD domain settings) | 4.1.5.2.1 |
| Modify LDAP advanced settings | PUT | (LDAP advanced) | 4.1.5.2.2 |
| Modify LDAP domain settings | PUT | (LDAP domain settings) | 4.1.5.2.3 |
| Create domain authentication server | POST | `LDAPConfig` | 4.3.3.1.1 |
| Initialize LDAP (advanced / domain) | PUT/POST | (LDAP init) | 4.1.5.4.1 / 4.1.5.4.2 |
| Test AD full domain name | POST | (AD FQDN test) | 4.1.5.4.6 |
| Test LDAP server IP | POST | (LDAP server IP test) | 4.1.5.4.7 |

### Current module status

No LDAP/AD/domain cmdlets exist. Documented, not implemented.

### Blast radius

**High.** Domain authentication governs administrative and (for NAS) end-user
access. A bad LDAP/AD config or an accidental "initialize" call can lock out
directory-backed logins, break NAS share authentication, and require console/
serial recovery. Test endpoints (FQDN/server-IP) are comparatively safe but
still touch live directory infrastructure.

### Proposed future cmdlet shapes

- `Get-DMLdapConfig` / `Get-DMAdConfig` — read-only (GET), ship first.
- `Get-DMLdapGroup` / `Get-DMLdapUser` — read-only lookups.
- `Test-DMLdapServer` / `Test-DMAdDomain` — connectivity/FQDN test (POST, but
  non-persisting probes; treat as low-mutation).
- `Set-DMLdapConfig` / `Set-DMAdConfig` — mutation (PUT), gated.
- `New-DMDomainAuthServer` — create auth server (POST), gated.
- Explicitly **no** `Initialize-*` cmdlet until a safe-guard design exists — the
  init endpoints are effectively destructive resets.

### Proposed safety posture

- Getters/tests: read-only, no `ShouldProcess`.
- All `Set-*`/`New-*`: `SupportsShouldProcess = $true`, **`ConfirmImpact = 'High'`**.
- Mock-only first; **live validation `SkippedUnsafe`** until reviewed.

### Open decisions

- Whether AD and LDAP get separate cmdlets or a shared `-DomainType` parameter.
- Whether to expose the init/reset endpoints at all.
- Credential handling for bind DN / bind password (reuse `[SecureString]`
  pattern already used by the user/certificate cmdlets; never plain text).

---

## 2. Email/SMTP alert notification

### Documented endpoints found

| Operation | Method | Resource | Reference section |
| --- | --- | --- | --- |
| Query email notifications | GET | `email` | 4.2.2.4.6 |
| Set email notifications | PUT | `email` | 4.2.2.5.6 |

Key documented fields on the `email` resource: `CMO_EMAIL_SUBJECT`,
`CMO_EMAIL_SENDER` (Mandatory), `CMO_EMAIL_LEVEL_E`, recipient list, SMTP server
host/port/auth. (Short-message notification 4.2.2.4.9/4.2.2.5.7 is adjacent but
out of scope for this note.)

### Current module status

No email/SMTP cmdlets exist. Documented, not implemented.

### Blast radius

**Medium (config) to High (operational).** Misconfiguring the SMTP relay or
recipient list silently suppresses alarm notifications — the array keeps running
but operators stop hearing about faults. The `Set` is a full PUT of the `email`
resource, so a partial write can clobber the sender/recipient set.

### Proposed future cmdlet shapes

- `Get-DMEmailNotification` — read-only (GET `email`), ship first.
- `Set-DMEmailNotification` — mutation (PUT `email`), gated. Must read-modify-
  write so unspecified fields are preserved, not blanked.
- `Send-DMTestEmail` only if a documented test endpoint is confirmed (none found
  in this pass — do not fabricate one).

### Proposed safety posture

- Getter: read-only, no `ShouldProcess`.
- `Set-DMEmailNotification`: `SupportsShouldProcess = $true`,
  **`ConfirmImpact = 'Medium'`** for routine field edits, escalate to `'High'`
  if the operation can disable notifications entirely.
- Mock-only first; **live validation `SkippedUnsafe`** until reviewed.

### Open decisions

- Read-modify-write vs. full-replace semantics for the PUT.
- Whether SMTP credentials belong in this cmdlet or a separate auth cmdlet.
- Confirm whether a non-persisting "send test email" endpoint exists.

---

## 3. Local login password / security policy

### Documented endpoints found

- Only **SNMP** security policy is a clearly documented standalone endpoint:
  Modify (4.2.1.3.4) and Query (4.2.1.4.4), on the `snmp` surface.
- Local-login password policy has **no dedicated documented endpoint** in this
  reference pass. `securityPolicy` appears only as an enum *field* on other
  resources (e.g. sections around lines 165386 / 167036 / 169806), not as its
  own manageable configuration object.

### Current module status

No password/security-policy cmdlets exist. Largely undocumented as a standalone
surface. Research only.

### Blast radius

**High.** Password/security-policy changes can lock out local administrators or
weaken the security posture of the array. The lack of a clearly documented
dedicated endpoint makes speculative implementation especially risky.

### Proposed safety posture

- **Research-only until a dedicated design and confirmed endpoint exist.**
- If/when implemented: `SupportsShouldProcess = $true`, **`ConfirmImpact = 'High'`**,
  mock-only first, live validation `SkippedUnsafe`.
- Do **not** send speculative REST bodies against undocumented password-policy
  paths.

### Open decisions

- Whether a documented local-login password-policy endpoint exists in a
  different reference version; confirm before any design work.
- Whether SNMP security policy warrants its own `Get/Set-DMSnmpSecurityPolicy`
  pair independent of the password-policy question.

---

## Mock-test strategy (applies to all three, when implemented)

- Mock the request helper (`Invoke-DeviceManager` / `Invoke-DMPagedRequest`) and
  assert the exact resource path and method.
- Getters: assert typed output and empty-result handling.
- Setters: assert `ShouldProcess` gating (`-WhatIf` performs no call) and that
  read-modify-write preserves untouched fields.
- No live connection in unit tests.

## Live-validation posture (all three)

`SkippedUnsafe` until a reviewed design exists. No live array access in Phase 07.

## Explicit non-implementation statement

Phase 07 implements **only** the read-only historical alarm/event getter
(`Get-DMAlarmHistory`, `GET alarm/historyalarm`). **No** LDAP/AD, **no**
Email/SMTP, and **no** password/security-policy code is included in Phase 07.
