# BAD006 UAT Form

## Project / Job Information

| Item | Details |
| --- | --- |
| Job ID | BAD006 |
| Job Name | Get-DcsLoginLogoutLogs |
| Environment | UAT |
| Application / System | DCS |
| Test Date |  |
| Tester |  |
| Business User / Reviewer |  |
| Release / Version |  |

## Testing Objective

The objective of this UAT is to verify that BAD006 correctly exports DCS user
login/logout records for the configured date range, creates the expected output
files, uploads the files to the configured SFTP destination, and handles normal
and exception scenarios according to business requirements.

Specifically, UAT should confirm that:

- Login records are selected by `LOGIN_DT` within the input date range.
- Logout records are selected by `LOGOUT_DT` within the input date range.
- User IDs matching the configured exclusion regex are not included in the
  exported output.
- The TXT output format is correct.
- The generated zip file name follows the expected naming convention.
- The SFTP upload completes successfully in UAT.
- Successfully uploaded files are moved to the backup directory.
- The configured date range is cleared after successful file generation.
- Log messages provide sufficient information for operation support and issue
  investigation.

## Scope of Testing

| In Scope | Out of Scope |
| --- | --- |
| BAD006 PowerShell batch execution | Production execution |
| UAT database records in `SYS_USER_LOGIN_TBL` | Changes to source application login/logout logic |
| TXT and zip output validation | SFTP server encryption implementation |
| SFTP upload and backup move | Network/firewall configuration outside BAD006 |
| Batch log validation | Scheduler configuration, unless explicitly tested |

## Preconditions

- UAT `config.ps1` has been reviewed and points to UAT database and SFTP values.
- `FromDate` and `ToDate` are set in `yyyy-MM-dd` format for the test case.
- UAT database contains suitable login/logout records for the selected date
  range.
- SFTP private key file exists and is readable by the account running BAD006.
- `psftp.exe` exists at the configured `SFTPProgram` path.
- The SFTP host key is either cached for the running Windows account or supported
  through the configured `SFTPHostKey`.
- Output, work, log, SFTP source, and backup directories are accessible.

## Test Data

| Test Data Item | Value / Description |
| --- | --- |
| FromDate |  |
| ToDate |  |
| Included USER_ID examples |  |
| Excluded USER_ID examples |  |
| Expected login count |  |
| Expected logout count |  |
| Expected output file prefix | `DCS_LOGIN_<from>_to_<to>_` |

## Test Cases

### TC01 - Batch Starts Successfully

| Field | Details |
| --- | --- |
| Objective | Verify BAD006 can start in UAT and pass batch active/owner checks. |
| Steps | Run `BAD006.ps1` from the BAD006 folder. |
| Expected Result | Log shows job start, loaded config/util paths, active batch status, and no startup errors. |
| Actual Result |  |
| Status | Pass / Fail |
| Remarks |  |

### TC02 - Export Uses Login/Logout Event Date Range

| Field | Details |
| --- | --- |
| Objective | Verify records are selected by `LOGIN_DT` / `LOGOUT_DT`, not update date. |
| Steps | Set `FromDate` and `ToDate`, seed or identify matching UAT records, then run BAD006. |
| Expected Result | Output includes only login events where `LOGIN_DT` is within range and logout events where `LOGOUT_DT` is within range. |
| Actual Result |  |
| Status | Pass / Fail |
| Remarks |  |

### TC03 - User ID Regex Exclusion

| Field | Details |
| --- | --- |
| Objective | Verify excluded `USER_ID` values are omitted from output. |
| Steps | Configure `UserIdFilterRegex`, run BAD006, and inspect the TXT content inside the zip. |
| Expected Result | USER_ID values matching the regex are not present; non-matching users remain present. |
| Actual Result |  |
| Status | Pass / Fail |
| Remarks |  |

### TC04 - TXT Output Format

| Field | Details |
| --- | --- |
| Objective | Verify TXT file format meets business requirement. |
| Steps | Extract the generated zip and review the TXT file. |
| Expected Result | Header and rows follow `[Login/out date] [USER_ID] [Action]`; rows are sorted by date, user, and action. |
| Actual Result |  |
| Status | Pass / Fail |
| Remarks |  |

### TC05 - Zip File Generation

| Field | Details |
| --- | --- |
| Objective | Verify zip file is generated in the configured output directory. |
| Steps | Run BAD006 with a valid date range. |
| Expected Result | Zip file is created using `DCS_LOGIN_<from>_to_<to>_<timestamp>.zip` naming convention. |
| Actual Result |  |
| Status | Pass / Fail |
| Remarks |  |

### TC06 - SFTP Upload and Backup Move

| Field | Details |
| --- | --- |
| Objective | Verify generated zip files are uploaded and moved to backup after success. |
| Steps | Run BAD006 and check SFTP destination, source directory, and backup directory. |
| Expected Result | File appears on SFTP destination; local source file is moved to backup after confirmed upload. |
| Actual Result |  |
| Status | Pass / Fail |
| Remarks |  |

### TC07 - Empty Date Range SFTP-Only Run

| Field | Details |
| --- | --- |
| Objective | Verify BAD006 skips generation but still uploads pending files when dates are empty. |
| Steps | Set `FromDate` and/or `ToDate` to empty, place a test zip in the SFTP source directory, then run BAD006. |
| Expected Result | Log shows generation skipped; pending file is uploaded and moved to backup if successful. |
| Actual Result |  |
| Status | Pass / Fail |
| Remarks |  |

### TC08 - Log Review

| Field | Details |
| --- | --- |
| Objective | Verify logs are clear and include appropriate log levels. |
| Steps | Review the generated `DCS_Batch_yyyyMMdd.log`. |
| Expected Result | Log contains `[INFO]`, `[WARN]`, `[ERROR]`, or `[DEBUG]` levels as appropriate and provides sufficient operational details. |
| Actual Result |  |
| Status | Pass / Fail |
| Remarks |  |

## Defect / Issue Log

| ID | Description | Severity | Owner | Status | Remarks |
| --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |

## UAT Summary

| Item | Result |
| --- | --- |
| Total Test Cases |  |
| Passed |  |
| Failed |  |
| Blocked / Not Run |  |
| Overall UAT Result | Pass / Fail |

## Sign-Off

| Role | Name | Signature / Confirmation | Date |
| --- | --- | --- | --- |
| Tester |  |  |  |
| Business User / Reviewer |  |  |  |
| IT / Support Representative |  |  |  |

## Final Remarks

