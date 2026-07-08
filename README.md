# Get-DcsLoginLogoutLogs

BAD006 (`Get-DcsLoginLogoutLogs`) is a PowerShell batch job that exports DCS
user login/logout audit records from `SYS_USER_LOGIN_TBL`, creates a zip file,
and uploads pending zip files by SFTP.

## Purpose

The job exports rows whose login/logout event date falls within the configured
date range and produces a formatted TXT file with one record per event:

```text
[Login/out date] [USER_ID] [Action]
2026-01-01 08:30:00,000 [USER01] [login]
```

The TXT file is compressed into:

```text
DCS_LOGIN_<from>_to_<to>_<timestamp>.zip
```

After successful upload, zip files are moved from the SFTP source directory to
the backup directory.

## Main files

| File | Description |
| --- | --- |
| `BAD006.ps1` | Entry point for the batch job |
| `config.ps1` | Environment, database, export, and SFTP configuration |
| `util.ps1` | Shared helper functions for logging, SQL, export, zip, SFTP, and batch status checks |
| `tests/` | Pester tests for regex filtering and SFTP helper behavior |

## Configuration

Configuration is defined in `config.ps1`.

### Export date range

Dates must use `yyyy-MM-dd` format:

```powershell
$FromDate = "2026-06-04"
$ToDate = "2026-06-30"
```

The range is inclusive. Login rows are selected by `LOGIN_DT`; logout rows are
selected by `LOGOUT_DT`. Internally, the SQL query uses an exclusive upper bound
for the next day to include all records on `ToDate`.

If either date is empty:

```powershell
$FromDate = ""
$ToDate = ""
```

BAD006 skips TXT/ZIP generation but still runs SFTP for files already waiting
in the SFTP source directory.

After a successful export and zip creation, BAD006 clears both dates in
`config.ps1` so the same date range is not exported again by accident.

### User ID filter

`UserIdFilterRegex` excludes matching `USER_ID` values from the TXT
export:

```powershell
$UserIdFilterRegex = "uat"
```

Matching is case-insensitive by PowerShell regex behavior. Leave it empty to
include all users.

### SFTP

BAD006 uses `psftp.exe` with a generated batch file:

```powershell
$SFTPProgram = "$intfRoot\sftp\psftp.exe"
$SFTPCert = "$intfRoot\sftp\dcs_to_itu4_uat_id_rsa.ppk"
$SFTPHostKey = ""
$SFTPHost = "sftplogsvruat.customs.hksarg"
$SFTPPort = "22"
$SFTPUser = "uat_sftp_log_dcs01"
$SFTPRemote = "/"
```

`SFTPHostKey` is optional. Leave it empty to use the cached host key, or set it
when the installed `psftp.exe` supports explicit host key verification.

Older PuTTY/psftp builds may report:

```text
psftp: unknown option "-hostkey"
```

When that happens, BAD006 logs the message and retries without `-hostkey`, which
means the host key must already be cached for the Windows account running the
batch job. To avoid manual prompts in unattended runs, either use a newer
`psftp.exe` that supports `-hostkey`, or pre-cache the host key under the same
Windows account that runs BAD006.

The SFTP sender:

1. Uploads every file in `SFTPSourceDirectory`
2. Logs each `psftp` output line and exit code
3. Treats a `local:... => remote:...` transfer line as success
4. Falls back to remote listing verification for accepted files that may be
   renamed by the server, such as `.zip.enc.zip`
5. Moves files to `SFTPBackupDirectory` only after confirmed success

## Execution flow

1. Load `config.ps1` and `util.ps1`
2. Check batch enable/status/owner through SQL batch parameters
3. If dates are configured:
   - parse dates
   - export login/logout TXT
   - zip the TXT file
   - remove the work TXT file
   - clear date range in `config.ps1`
4. Upload all pending zip files from the SFTP source directory
5. Move successfully uploaded files to backup
6. Exit `0` on success or `1` when export/SFTP errors occur

## Running

From the BAD006 folder:

```powershell
pwsh -File .\BAD006.ps1
```

On the production Windows host, it is normally run by the batch scheduler.

## Logging

Log lines include a timestamp and level:

```text
[2026-07-08 09:50:00] [INFO] BAD006 completed
[2026-07-08 09:50:00] [ERROR] One or more files failed to upload by SFTP.
```

Levels used by BAD006:

| Level | Meaning |
| --- | --- |
| `INFO` | Normal job progress |
| `WARN` | Non-fatal abnormal condition or fallback behavior |
| `ERROR` | Failure that causes a failed operation or non-zero exit |
| `DEBUG` | Diagnostic details such as loaded paths and raw SFTP output |

## Tests and validation

Run Pester tests:

```powershell
Invoke-Pester -Path ./tests -Output Detailed
```

Parse-check scripts:

```powershell
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile("./BAD006.ps1", [ref]$tokens, [ref]$errors)
$errors
```

Run ScriptAnalyzer:

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error,Warning
```

Some warnings are expected because `config.ps1` variables are consumed by
dot-sourcing and `Log` writes to both file and console.