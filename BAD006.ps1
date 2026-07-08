#*****************************************************************************
#
# File Name:           BAD006.ps1
#
# Job Name:            BAD006
# Version:             1.0.0
#
# Purpose:             Export DCS user login/logout audit records from
#                      SYS_USER_LOGIN_TBL for a configured login/logout date
#                      range. The job writes a formatted TXT file, compresses it
#                      into a DCS_LOGIN zip file, uploads pending zip files by
#                      SFTP, and moves successfully uploaded files to backup.
#
# Notes:               FromDate and ToDate are one-time control
#                      values. When both dates are empty, file generation is
#                      skipped but SFTP still runs for pending files.
#
# Change Log:
#   2026-07-07  v1.0.0  Initial BAD006 implementation for login/logout export.
#   2026-07-07  v1.0.0  Added TXT output, zip creation, work-file cleanup, and
#                       SFTP upload with backup move after confirmed success.
#   2026-07-07  v1.0.0  Added configurable USER_ID regex exclusion filter.
#   2026-07-07  v1.0.0  Added yyyy-MM-dd config date validation and automatic
#                       clearing of FromDate/ToDate after successful export.
#   2026-07-07  v1.0.0  Improved psftp handling for PowerShell Stop preference,
#                       optional host key, transfer logging, and remote verify.
#   2026-07-07  v1.0.0  Changed export filtering from LAST_UPD_DT to actual
#                       event dates: LOGIN_DT for login, LOGOUT_DT for logout.
#
#*****************************************************************************

[CmdletBinding()]
Param()

$ErrorActionPreference = "Stop"

$parent = (Get-Item $MyInvocation.MyCommand.Path).DirectoryName
$me = (Get-Item $MyInvocation.MyCommand.Path).BaseName
$common = Join-Path (Split-Path -Parent $parent) "Common"

# Prefer the shared batch Common folder when it exists; otherwise keep BAD006
# self-contained by loading config/util from the script directory.
if (-not (Test-Path (Join-Path $common "config.ps1"))) {
    $common = $parent
}

$configPath = Join-Path $common "config.ps1"
$utilPath = Join-Path $common "util.ps1"

. $configPath
. $utilPath

if ([string]::IsNullOrWhiteSpace($BatchJobName)) {
    $jobName = $me
}
else {
    $jobName = $BatchJobName.Trim()
}
$runTimestamp = Get-Date -Format "yyyyMMddHHmmss"
$logFile = Join-Path $LogDirectory ("DCS_Batch_{0}.log" -f (Get-Date -Format "yyyyMMdd"))

try {
    EnsureDirectory $LogDirectory
    EnsureDirectory $WorkDirectory
    EnsureDirectory $OutputDirectory
    EnsureDirectory $SFTPSourceDirectory
    EnsureDirectory $SFTPBackupDirectory

    Log "$me start running"
    Log "Loaded config: $configPath" "DEBUG"
    Log "Loaded util: $utilPath" "DEBUG"

    if ((IsActiveJob $jobName) -ne $true) {
        Log "Job [$jobName] is inactive. Script [$me] is terminated." "WARN"
        return 0
    }

    $skipGenerate = [string]::IsNullOrWhiteSpace($FromDate) -or [string]::IsNullOrWhiteSpace($ToDate)

    # Empty dates intentionally skip export generation but still allow the SFTP
    # step to send any files that are already waiting in the source directory.
    if ($skipGenerate) {
        Log "FromDate or ToDate is empty. Skipping file generation." "WARN"
    }
    else {
        $fromDate = ParseConfigDate $FromDate "FromDate"
        $toDate = ParseConfigDate $ToDate "ToDate"

        if ($fromDate -gt $toDate) {
            throw "FromDate must be earlier than or equal to ToDate."
        }

        $fromDateText = $fromDate.ToString("yyyyMMdd")
        $toDateText = $toDate.ToString("yyyyMMdd")
        $toDateExclusiveText = $toDate.AddDays(1).ToString("yyyyMMdd")

        Log "Exporting SYS_USER_LOGIN_TBL where LOGIN_DT/LOGOUT_DT is from $fromDateText to $toDateText inclusive"

        $baseFileName = "DCS_LOGIN_{0}_to_{1}_{2}" -f $fromDateText, $toDateText, $runTimestamp
        $txtFileName = "$baseFileName.txt"
        $zipFileName = "DCS_LOGIN_{0}_to_{1}_{2}.zip" -f $fromDateText, $toDateText, $runTimestamp
        $txtPath = Join-Path $WorkDirectory $txtFileName
        $zipPath = Join-Path $OutputDirectory $zipFileName

        if (Test-Path $txtPath) {
            Remove-Item $txtPath -Force
        }

        if (Test-Path $zipPath) {
            Remove-Item $zipPath -Force
        }

        $txtSql = @"
SELECT FORMAT([Login/out date], 'yyyy-MM-dd HH:mm:ss,fff') AS [Login/out date],
       USER_ID,
       [Action]
FROM (
    SELECT LOGIN_DT AS [Login/out date],
           USER_ID,
           'login' AS [Action]
    FROM SYS_USER_LOGIN_TBL
    WHERE LOGIN_DT >= CONVERT(datetime, '$fromDateText', 112)
      AND LOGIN_DT < CONVERT(datetime, '$toDateExclusiveText', 112)
    UNION ALL
    SELECT logoutEvents.LOGOUT_DT AS [Login/out date],
           logoutEvents.USER_ID,
           'logout' AS [Action]
    FROM (
        -- Multiple rows can share the same USER_ID/LOGOUT_DT. Group here to
        -- keep logout records unique while preserving all login events above.
        SELECT USER_ID,
               LOGOUT_DT
        FROM SYS_USER_LOGIN_TBL
        WHERE LOGOUT_DT >= CONVERT(datetime, '$fromDateText', 112)
          AND LOGOUT_DT < CONVERT(datetime, '$toDateExclusiveText', 112)
        GROUP BY USER_ID, LOGOUT_DT
    ) logoutEvents
) loginEvents
ORDER BY [Login/out date], USER_ID, [Action]
"@

        $txtExportResult = SqlExportLoginOutText $txtSql $txtPath $true $UserIdFilterRegex

        if ($txtExportResult -ne 0) {
            throw "Failed to export SYS_USER_LOGIN_TBL to TXT."
        }

        Log "TXT generated: $txtPath"

        $zipResult = ZipFiles @($txtPath) $zipPath

        if ($zipResult -ne 0) {
            throw "Failed to create zip file: $zipPath"
        }

        Log "Zip generated: $zipPath"

        if (Test-Path $txtPath) {
            Remove-Item $txtPath -Force
            Log "Removed work file: $txtPath"
        }

        if ($SFTPSourceDirectory -ne $OutputDirectory) {
            Copy-Item $zipPath (Join-Path $SFTPSourceDirectory $zipFileName) -Force
            Log "Zip copied to SFTP source directory: $SFTPSourceDirectory"
        }

        # The date range is a one-time work instruction. Clear it only after the
        # export and zip are created successfully so retries do not duplicate work.
        Clear-DateRangeConfig $configPath
        Log "Cleared FromDate and ToDate in config."
    }

    # Upload every file currently in the source directory, not only the file
    # generated in this run. This lets the job recover files left by prior
    # failed SFTP attempts.
    $sendResult = SendDirectoryBySFTP `
        $SFTPCert `
        $SFTPPort `
        $SFTPUser `
        $SFTPHost `
        $SFTPRemote `
        $SFTPSourceDirectory `
        $SFTPBackupDirectory `
        $SFTPHostKey

    if ($sendResult -ne $true) {
        Log "One or more files failed to upload by SFTP." "ERROR"
        Log "$me completed with SFTP upload errors" "ERROR"
        return 1
    }

    Log "$me completed"
    return 0
}
catch {
    Log $_.Exception.Message "ERROR"
    return 1
}
