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
$BAD006_FromDate = "2026-06-04"
$BAD006_ToDate = "2026-06-30"
```

The range is inclusive. Login rows are selected by `LOGIN_DT`; logout rows are
selected by `LOGOUT_DT`. Internally, the SQL query uses an exclusive upper bound
for the next day to include all records on `BAD006_ToDate`.

If either date is empty:

```powershell
$BAD006_FromDate = ""
$BAD006_ToDate = ""
```

BAD006 skips TXT/ZIP generation but still runs SFTP for files already waiting
in the SFTP source directory.

After a successful export and zip creation, BAD006 clears both dates in
`config.ps1` so the same date range is not exported again by accident.

### User ID filter

`BAD006_UserIdFilterRegex` excludes matching `USER_ID` values from the TXT
export:

```powershell
$BAD006_UserIdFilterRegex = "uat"
```

Matching is case-insensitive by PowerShell regex behavior. Leave it empty to
include all users.

### SFTP

BAD006 uses `psftp.exe` with a generated batch file:

```powershell
$BAD006_SFTP_Program = "$intfRoot\sftp\psftp.exe"
$BAD006_SFTP_Cert = "$intfRoot\sftp\dcs_to_itu4_uat_id_rsa.ppk"
$BAD006_SFTP_HostKey = ""
$BAD006_SFTP_Host = "sftplogsvruat.customs.hksarg"
$BAD006_SFTP_Port = "22"
$BAD006_SFTP_User = "uat_sftp_log_dcs01"
$BAD006_SFTP_Remote = "/"
```

`BAD006_SFTP_HostKey` is optional. Leave it empty to use the cached host key, or
set it when the environment requires explicit host key verification.

The SFTP sender:

1. Uploads every file in `BAD006_SFTPSourceDirectory`
2. Logs each `psftp` output line and exit code
3. Treats a `local:... => remote:...` transfer line as success
4. Falls back to remote listing verification for accepted files that may be
   renamed by the server, such as `.zip.enc.zip`
5. Moves files to `BAD006_SFTPBackupDirectory` only after confirmed success

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