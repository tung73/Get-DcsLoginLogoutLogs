# AGENTS.md

## Cursor Cloud specific instructions

### What this is
This repo is the **BAD006** batch job (`Get-DcsLoginLogoutLogs`): a Windows **PowerShell** job that exports `SYS_USER_LOGIN_TBL` login/logout rows from a SQL Server by `LAST_UPD_DT` range, writes a TXT output, zips it, and uploads the zip via SFTP. It excludes `USER_ID` values matching `BAD006_UserIdFilterRegex` and de-duplicates logout rows with the same user/time. It is not a service — it is a one-shot script. Files: `BAD006.ps1` (entry point), `util.ps1` (functions), `config.ps1` (paths/connection/SFTP settings), `README.md`.

### Runtime
- PowerShell 7 (`pwsh`) is installed in the VM snapshot. `System.Data.SqlClient` (used by `util.ps1`) is available under `pwsh`.
- There is no package manager, lockfile, build step, or automated test suite in this repo.

### Lint / parse-check (these are the "build"/"test" for this repo)
- Lint: `pwsh -NoProfile -c 'Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error,Warning'` (PSScriptAnalyzer). Current code is clean of Errors; remaining items are pre-existing Warnings (e.g. `Write-Host`, `$null`-on-right comparisons, "unused" `config.ps1` vars that are actually consumed via dot-sourcing).
- Parse-check a script: `[System.Management.Automation.Language.Parser]::ParseFile(<path>, [ref]$t, [ref]$e)` and inspect `$e`.

### Important environment caveats (production-only dependencies)
- `config.ps1` targets an **internal HK Customs production** SQL Server (`prd.db.dcs.customs.hksarg`) and SFTP host (`eservices.customs.hksarg`) using **Windows paths** (`O:\Batch`, UNC shares). None of these are reachable from the cloud VM.
- The SFTP step (`sFTPSend` / `SendDirectoryBySFTP`) shells out to Windows-only `psftp.exe` configured by `BAD006_SFTP_Program` in `config.ps1`. It is not in the repo, so **SFTP cannot run on Linux**.
- Therefore running `BAD006.ps1` unmodified end-to-end will fail in this env (Windows paths + batch-status gating via `SYS_BATCH_PARM_VW` / `Batch_GetJobStatus` + SFTP). Do **not** treat that as a regression.

### How to exercise the core export pipeline locally
The runnable core is `SqlExportLoginOutText` and `ZipFiles` from `util.ps1`. To test without touching prod:
1. Run a local SQL Server (Docker): `docker run -d --name mssql -e ACCEPT_EULA=Y -e MSSQL_SA_PASSWORD=Dev@Passw0rd123 -p 1433:1433 mcr.microsoft.com/mssql/server:2022-latest`. Docker is installed but **`dockerd` is not managed by systemd here** — start it manually (e.g. `sudo dockerd > /tmp/dockerd.log 2>&1 &`) before using `docker`.
2. Create DB `DCDBDP` + table `SYS_USER_LOGIN_TBL` (columns include `LAST_UPD_DT`, `LOGIN_DT`, `LOGOUT_DT`, and `USER_ID`) and seed rows.
3. In a harness script: dot-source `util.ps1`, set `$connectionString` to the local server (`Server=localhost,1433;...;TrustServerCertificate=True;`), set `$logFile` (required by `Log`), then call `SqlExportLoginOutText <sql> <txtPath>` and `ZipFiles @(<txtPath>) <zipPath>`. Do not edit `config.ps1`/`util.ps1` — override the variables in the harness instead.
