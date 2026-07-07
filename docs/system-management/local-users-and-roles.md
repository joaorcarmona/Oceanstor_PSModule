# Local Users and Roles System Management

## Scope

Management of DeviceManager **local user accounts** (creation, modification,
removal, lock/unlock, session termination, password reset) and **roles**
(built-in and custom roles, role permissions). LDAP/AD/domain user management
is **not implemented**. Detailed internal gap-analysis notes are archived outside the public documentation set.

## Cmdlets

| Cmdlet | Action | REST resource | Mutating | ShouldProcess |
|---|---|---|---|---:|
| `Get-DMLocalUser` | List local users or one by `-Id` | `user`, `user/<id>` | No | — |
| `New-DMLocalUser` | Create a local user | `user` (POST) | Yes | Yes |
| `Set-DMLocalUser` | Modify description, password, role | `user/<id>` (PUT) | Yes | Yes |
| `Remove-DMLocalUser` | Delete a local user | `user/<id>` (DELETE) | Yes | Yes |
| `Lock-DMLocalUser` | Lock an account | `lockuser/<id>` (PUT) | Yes | Yes |
| `Unlock-DMLocalUser` | Unlock an account | `unlockuser/<id>` (PUT) | Yes | Yes |
| `Disable-DMLocalUserSession` | Force user sessions offline | `offline_user/<id>` (PUT) | Yes | Yes |
| `Reset-DMLocalUserPassword` | Initialize/reset a user password | `initialize_user_pwd/<id>` (PUT) | Yes | Yes |
| `Get-DMRole` | List roles or one by `-Id` | `role`, `role/<id>` | No | — |
| `Get-DMRolePermission` | List permissions available to a role owner group | `querying_permissions_available` | No | — |
| `New-DMRole` | Create a custom role | `role` (POST) | Yes | Yes |
| `Set-DMRole` | Modify a role name/description | `role/<id>` (PUT) | Yes | Yes |
| `Remove-DMRole` | Delete a role | `role` (DELETE) | Yes | Yes |

Key parameters:

- `New-DMLocalUser -Name -Password -RoleId [-Description] [-Property]`
- `Set-DMLocalUser -Id [-Description] [-Password] [-OldPassword] [-RoleId] [-Property]`
- `New-DMRole -Name [-Description] [-RoleOwnerGroup] [-RoleSource] [-Property]`
- Password parameters accept `SecureString` values (verified by unit tests).
- `-Property` accepts a hashtable of extra REST body fields on all mutators.

Getters return `OceanStorLocalUser`, `OceanStorRole`, and
`OceanStorRolePermission` typed objects. Identity values containing `/` are
URL-encoded automatically.

## Common Workflows

1. **Audit accounts and roles** — list users, their role assignment, and the
   available roles.
2. **Provision an automation account** — create a role-scoped user for
   scripting, then rotate its password.
3. **Incident response** — lock an account and force its sessions offline.

## Examples

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
$storage = Connect-deviceManager -Hostname $storageIP -Credential $cred -PassThru

# Audit: list users and roles
Get-DMLocalUser -WebSession $storage
Get-DMRole -WebSession $storage
Get-DMRolePermission -WebSession $storage -RoleOwnerGroup '1'

# Create a read-only automation user (always preview first)
$pwd = Read-Host -AsSecureString -Prompt 'New user password'
New-DMLocalUser -WebSession $storage -Name 'automation_ro' -Password $pwd -RoleId '5' -WhatIf
New-DMLocalUser -WebSession $storage -Name 'automation_ro' -Password $pwd -RoleId '5'

# Lock a user and terminate its sessions
Lock-DMLocalUser -WebSession $storage -Id 'automation_ro'
Disable-DMLocalUserSession -WebSession $storage -Id 'automation_ro'

# Remove the user (pipeline form)
Get-DMLocalUser -WebSession $storage -Id 'automation_ro' | Remove-DMLocalUser -WebSession $storage
```

## Safety Notes

- These cmdlets are classified `AuthenticationOrAccessMutation`
  (see [SAFETY-AND-LIVE-VALIDATION.md](SAFETY-AND-LIVE-VALIDATION.md)).
- **Never** modify, lock, or remove the built-in `admin` account or any
  pre-existing account in live validation.
- Removing or re-roling a user can lock out other automation. Prefer creating
  a dedicated test user and deleting it by captured ID.
- Role deletion may be rejected while users are assigned; delete test users
  before deleting the test role.
- `Reset-DMLocalUserPassword` invalidates existing credentials — never run it
  against a pre-existing account.

## Integrity Test Coverage

- Read-only: `Get-DMLocalUser`, `Get-DMRole`, `Get-DMRolePermission` are
  validated by `Tests/Integration/Private/ReadValidation.ps1`.
- Mutating: **no integration workflow exists.** All user/role mutators are
  reported as `SkippedUnsafe` in every run — global/authentication
  mutations are not exercised by the integrity harness unless a dedicated
  safe workflow exists for them.
- Unit tests: `Tests/Unit/Public/Get-SystemConfiguration.Tests.ps1` and
  `Set-SystemConfiguration.Tests.ps1` cover getters, CRUD, lock/unlock,
  session disable, password reset, SecureString handling, and `-WhatIf`.

## Known Gaps

- ~~`Get-DMRole` list mode hangs (bug B-1)~~ — **fixed**: the lab array's
  `role` REST endpoint does not honor `range` paging (it pads the response
  with copies of the first role), so list mode now queries the `role`
  resource unpaged. `Get-DMRole -Id <id>` is unchanged. Regression unit
  tests in `Get-SystemConfiguration.Tests.ps1` simulate the padded-page
  behavior; `Invoke-DMPagedRequest` was left untouched.
- No LDAP/AD/domain authentication cmdlets (`UnsupportedFeatureGap`).
- No password/security-policy cmdlets for local login policy (the only policy
  surface implemented is the SNMP security policy).
- No integration workflow for a test-owned user + role lifecycle
  (`IntegrityTestGap`).

## Related Files

- `POSH-Oceanstor/Public/*DMLocalUser*.ps1`, `*DMRole*.ps1`
- `POSH-Oceanstor/Private/class-OceanStorSystemConfiguration.ps1`
- `Tests/Unit/Public/Get-SystemConfiguration.Tests.ps1`
- `Tests/Unit/Public/Set-SystemConfiguration.Tests.ps1`
- `Tests/Integration/Private/ReadValidation.ps1`
