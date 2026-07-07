#*****************************************************************************
#
# File Name:           BAD006.ps1
#
# Purpose:             Export SYS_USER_LOGIN_TBL login/logout rows by
#                      LAST_UPD_DT range, zip the TXT output, and send files
#                      by SFTP.
#
#*****************************************************************************

[CmdletBinding()]
Param()

$ErrorActionPreference = "Stop"

$parent = (Get-Item $MyInvocation.MyCommand.Path).DirectoryName
$me = (Get-Item $MyInvocation.MyCommand.Path).BaseName
$common = Join-Path (Split-Path -Parent $parent) "Common"

if (-not (Test-Path (Join-Path $common "config.ps1"))) {
    $common = $parent
}

$configPath = Join-Path $common "config.ps1"
$utilPath = Join-Path $common "util.ps1"

. $configPath
. $utilPath

if ([string]::IsNullOrWhiteSpace($BAD006_UtilVersion)) {
    $BAD006_UtilVersion = "unknown"
}

if ([string]::IsNullOrWhiteSpace($BAD006_JobName)) {
    $jobName = $me
}
else {
    $jobName = $BAD006_JobName.Trim()
}
$runTimestamp = Get-Date -Format "yyyyMMddHHmmss"
$logFile = Join-Path $BAD006_LogDirectory ("DCS_Batch_{0}.log" -f (Get-Date -Format "yyyyMMdd"))

try {
    EnsureDirectory $BAD006_LogDirectory
    EnsureDirectory $BAD006_WorkDirectory
    EnsureDirectory $BAD006_OutputDirectory
    EnsureDirectory $BAD006_SFTPSourceDirectory
    EnsureDirectory $BAD006_SFTPBackupDirectory

    Log "$me start running"
    Log "Loaded config: $configPath"
    Log "Loaded util: $utilPath"
    Log "Loaded util version: $BAD006_UtilVersion"

    if ((IsActiveJob $jobName) -ne $true) {
        Log "Job [$jobName] is inactive. Script [$me] is terminated."
        return 0
    }

    $skipGenerate = [string]::IsNullOrWhiteSpace($BAD006_FromDate) -or [string]::IsNullOrWhiteSpace($BAD006_ToDate)

    if ($skipGenerate) {
        Log "BAD006_FromDate or BAD006_ToDate is empty. Skipping file generation."
    }
    else {
        $fromDate = ParseConfigDate $BAD006_FromDate "BAD006_FromDate"
        $toDate = ParseConfigDate $BAD006_ToDate "BAD006_ToDate"

        if ($fromDate -gt $toDate) {
            throw "BAD006_FromDate must be earlier than or equal to BAD006_ToDate."
        }

        $fromDateText = $fromDate.ToString("yyyyMMdd")
        $toDateText = $toDate.ToString("yyyyMMdd")
        $toDateExclusiveText = $toDate.AddDays(1).ToString("yyyyMMdd")

        Log "Exporting SYS_USER_LOGIN_TBL where LAST_UPD_DT is from $fromDateText to $toDateText inclusive"

        $baseFileName = "DCS_LOGIN_{0}_to_{1}_{2}" -f $fromDateText, $toDateText, $runTimestamp
        $txtFileName = "$baseFileName.txt"
        $zipFileName = "DCS_LOGIN_{0}_to_{1}_{2}.zip" -f $fromDateText, $toDateText, $runTimestamp
        $txtPath = Join-Path $BAD006_WorkDirectory $txtFileName
        $zipPath = Join-Path $BAD006_OutputDirectory $zipFileName

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
    WHERE LAST_UPD_DT >= CONVERT(datetime, '$fromDateText', 112)
      AND LAST_UPD_DT < CONVERT(datetime, '$toDateExclusiveText', 112)
      AND LOGIN_DT IS NOT NULL
    UNION ALL
    SELECT logoutEvents.LOGOUT_DT AS [Login/out date],
           logoutEvents.USER_ID,
           'logout' AS [Action]
    FROM (
        SELECT USER_ID,
               LOGOUT_DT
        FROM SYS_USER_LOGIN_TBL
        WHERE LAST_UPD_DT >= CONVERT(datetime, '$fromDateText', 112)
          AND LAST_UPD_DT < CONVERT(datetime, '$toDateExclusiveText', 112)
          AND LOGOUT_DT IS NOT NULL
        GROUP BY USER_ID, LOGOUT_DT
    ) logoutEvents
) loginEvents
ORDER BY [Login/out date], USER_ID, [Action]
"@

        $txtExportResult = SqlExportLoginOutText $txtSql $txtPath $true $BAD006_UserIdFilterRegex

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

        if ($BAD006_SFTPSourceDirectory -ne $BAD006_OutputDirectory) {
            Copy-Item $zipPath (Join-Path $BAD006_SFTPSourceDirectory $zipFileName) -Force
            Log "Zip copied to SFTP source directory: $BAD006_SFTPSourceDirectory"
        }

        Clear-Bad006DateRangeConfig $configPath
        Log "Cleared BAD006_FromDate and BAD006_ToDate in config."
    }

    $sendResult = SendDirectoryBySFTP `
        $BAD006_SFTP_Cert `
        $BAD006_SFTP_Port `
        $BAD006_SFTP_User `
        $BAD006_SFTP_Host `
        $BAD006_SFTP_Remote `
        $BAD006_SFTPSourceDirectory `
        $BAD006_SFTPBackupDirectory

    if ($sendResult -ne $true) {
        Log "One or more files failed to upload by SFTP."
        Log "$me completed with SFTP upload errors"
        return 1
    }

    Log "$me completed"
    return 0
}
catch {
    Log $_.Exception.Message
    return 1
}
