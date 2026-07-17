# Debug / REST Request Tracing — POSH-Oceanstor

When something the module does against the array doesn't behave as expected, you
usually need to see the raw conversation: **what the module sent** (method, URI,
body) and **what the array returned** (HTTP status, OceanStor `error.code`, and
the response payload). The debug tracer captures exactly that for every REST call,
with no code changes to the cmdlet you're debugging.

Tracing is off by default and has zero cost until you enable it. Secrets
(`password`, `token`, `secret`, `community`, `iBaseToken`) are always redacted.

## Cmdlets

| Cmdlet | Purpose |
|---|---|
| `Enable-DMRequestTrace` | Turn tracing on. Prints each request live and keeps entries in memory. |
| `Disable-DMRequestTrace` | Turn tracing off. `-Clear` also empties the buffer. |
| `Get-DMRequestTrace` | Return the captured entries. `-Last N`, `-Clear`. |
| `Clear-DMRequestTrace` | Empty the in-memory buffer without disabling tracing. |

These belong to the always-on `Diagnostics` feature (see `Get-DMFeature`).

## Trace depth

`Enable-DMRequestTrace -DebugDepth <1|2>`:

- **Depth 1** (default) — the structured view: vendor, host, version, method,
  URI, request body (as an object), HTTP status, OceanStor `error.code` /
  description, and the response.
- **Depth 2** — the raw wire view: everything in depth 1 **plus** the exact JSON
  string sent on the wire, the request headers (token redacted), and the response
  re-serialized to JSON. Use this when you suspect a serialization or header
  problem.

## Quickstart

```powershell
Import-Module POSH-Oceanstor

$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
Connect-deviceManager -Hostname 10.10.10.24 -Credential $cred -SkipCertificateCheck

Enable-DMRequestTrace          # depth 1, live console + collected in memory

Get-DMSystem                   # run whatever you want to debug

Disable-DMRequestTrace
```

Each call prints a block as it happens. Example, captured live against a
Dorado 5000 V6 (`Get-DMSystem`):

```
[Huawei OceanStor | 10.10.10.24 | vV600R005C27]
  -> GET https://10.10.10.24:8088/deviceManager/rest/2102355GVCTUP4910007/system/
  <- HTTP 200  error.code=0  (42.35 ms)
     response: {"data":{"NAME":"HWPTLABSTG006","PRODUCTVERSION":"V600R005C27", ... },"error":{"code":0,"description":"0"}}
```

## Debugging a write (PUT/POST) at depth 2

Depth 2 is the most useful mode when a create/modify call is rejected, because it
shows the **exact body** the array received. This is what caught the OceanStor
modify-body contract issues (mandatory `ID` field missing from the body).

```powershell
Enable-DMRequestTrace -DebugDepth 2

Set-DMLun -LunId 5 -NewName 'renamed-lun'    # or any create/modify cmdlet
```

```
[Huawei OceanStor | 10.10.10.24 | vV600R005C27]
  -> PUT https://10.10.10.24:8088/deviceManager/rest/2102355GVCTUP4910007/lun/5
     body: {
  "NAME": "renamed-lun",
  "ID": "5"
}
     headers: {"iBaseToken":"[REDACTED]"}
  <- HTTP 200  error.code=0  (49.2 ms)
     response: {"error":{"code":0,"description":"0"}}
```

If the array rejects the request, the response line turns red and shows the
business error, e.g. `error.code=1077949001` with its description.

## Collecting instead of watching

For scripted runs, suppress the console with `-Quiet` and inspect the buffer
afterwards:

```powershell
Enable-DMRequestTrace -DebugDepth 2 -Quiet

Get-DMlun -Name 'app-*' | Out-Null

# Most recent request, all fields
Get-DMRequestTrace -Last 1 | Format-List

# Just the wire body of the last call
(Get-DMRequestTrace -Last 1).RawJsonBody

# Export the whole session for a bug report
Get-DMRequestTrace | ConvertTo-Json -Depth 12 | Set-Content .\dm-trace.json

Disable-DMRequestTrace -Clear
```

## Writing every request to a log file

`-LogPath` appends one compact JSON object per request (JSON Lines). Combine with
or without `-Quiet`:

```powershell
Enable-DMRequestTrace -DebugDepth 2 -LogPath .\dm-debug.jsonl

# ...run your workflow...

Disable-DMRequestTrace
Get-Content .\dm-debug.jsonl | Select-Object -First 1 | ConvertFrom-Json
```

## Entry fields

Each entry from `Get-DMRequestTrace` (and each JSON line in the log file):

| Field | Notes |
|---|---|
| `Timestamp`, `DurationMs` | When the request started and how long it took. |
| `Vendor`, `Hostname`, `Version` | `Huawei OceanStor`, and the connected array's host + software version. |
| `Method`, `Uri`, `ApiV2` | HTTP verb, full request URI, whether the `/api/v2/` endpoint was used. |
| `StatusCode` | HTTP status. Defaults to `200` on hosts without PowerShell 7.4+ status capture — OceanStor reports real failures in `error.code`, not the HTTP status. |
| `Request` | Request body as an object (secrets redacted). |
| `Response` | Response object, including the `error.code` / `description` envelope. |
| `Exception` | Set instead of `Response` when the call threw. |
| `RawJsonBody`, `RawResponse`, `Headers` | **Depth 2 only** — exact wire JSON in/out and the request headers (token redacted). |

## Notes

- **Secrets are redacted** in bodies and headers by key name (`password`,
  `passwd`, `pwd`, `token`, `secret`, `community` — this covers `iBaseToken`).
  The login exchange happens outside this REST layer, so passwords never reach a
  trace body.
- **`RawResponse`** (depth 2) is the parsed response re-serialized to JSON, not
  the literal transport bytes — `Invoke-RestMethod` deserializes before the
  module sees it.
- **`StatusCode`** is the HTTP status; for OceanStor the meaningful result code
  is the body's `error.code`, which the console line shows alongside it.
- Tracing state is module-scoped and per-session; `Disable-DMRequestTrace` (or
  ending the session) stops it. It is safe to leave enabled during an
  interactive debugging session.

## See also

- [Testing guide](../testing/README.md)
- [Live validation safety](../testing/live-validation-safety.md)
