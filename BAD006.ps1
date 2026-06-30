#*****************************************************************************
#
# File Name:           BAD006.ps1
#
# Purpose:             Export SYS_USER_LOGIN_TBL rows by last_up_date range,
#                      zip the CSV, and send files by SFTP.
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

. (Join-Path $common "config.ps1")
. (Join-Path $common "util.ps1")

$jobName = $me
$runTimestamp = Get-Date -Format "yyyyMMddHHmmss"
$logFile = Join-Path $BAD006_LogDirectory ("{0}.{1}.log" -f $jobName, $runTimestamp)

try {
    EnsureDirectory $BAD006_LogDirectory
    EnsureDirectory $BAD006_WorkDirectory
    EnsureDirectory $BAD006_OutputDirectory
    EnsureDirectory $BAD006_SFTPSourceDirectory

    Log "$me start running"

    if ((IsActiveJob $jobName) -ne $true) {
        Log "Job [$jobName] is inactive. Script [$me] is terminated."
        return 0
    }

    $fromDate = ParseConfigDate $BAD006_FromDate "BAD006_FromDate"
    $toDate = ParseConfigDate $BAD006_ToDate "BAD006_ToDate"

    if ($fromDate -gt $toDate) {
        throw "BAD006_FromDate must be earlier than or equal to BAD006_ToDate."
    }

    $fromDateText = $fromDate.ToString("yyyyMMdd")
    $toDateText = $toDate.ToString("yyyyMMdd")
    $toDateExclusiveText = $toDate.AddDays(1).ToString("yyyyMMdd")

    Log "Exporting SYS_USER_LOGIN_TBL where last_up_date is from $fromDateText to $toDateText inclusive"

    $csvFileName = "DCS_LOGIN_{0}_to_{1}_{2}.csv" -f $fromDateText, $toDateText, $runTimestamp
    $zipFileName = "DCS_LOGIN_{0}_to_{1}_{2}.zip" -f $fromDateText, $toDateText, $runTimestamp
    $csvPath = Join-Path $BAD006_WorkDirectory $csvFileName
    $zipPath = Join-Path $BAD006_OutputDirectory $zipFileName

    if (Test-Path $csvPath) {
        Remove-Item $csvPath -Force
    }

    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }

    $sql = @"
SELECT *
FROM SYS_USER_LOGIN_TBL
WHERE last_up_date >= CONVERT(datetime, '$fromDateText', 112)
  AND last_up_date < CONVERT(datetime, '$toDateExclusiveText', 112)
ORDER BY last_up_date
"@

    $exportResult = SqlExportToCSV $sql $csvPath

    if ($exportResult -ne 0) {
        throw "Failed to export SYS_USER_LOGIN_TBL to CSV."
    }

    Log "CSV generated: $csvPath"

    $zipResult = ZipFiles @($csvPath) $zipPath

    if ($zipResult -ne 0) {
        throw "Failed to create zip file: $zipPath"
    }

    Log "Zip generated: $zipPath"

    if ($BAD006_SFTPSourceDirectory -ne $BAD006_OutputDirectory) {
        Copy-Item $zipPath (Join-Path $BAD006_SFTPSourceDirectory $zipFileName) -Force
        Log "Zip copied to SFTP source directory: $BAD006_SFTPSourceDirectory"
    }

    $sendResult = SendDirectoryBySFTP `
        $BAD006_SFTP_Cert `
        $BAD006_SFTP_Port `
        $BAD006_SFTP_User `
        $BAD006_SFTP_Host `
        $BAD006_SFTP_Remote `
        $BAD006_SFTPSourceDirectory

    if ($sendResult -ne $true) {
        throw "One or more files failed to upload by SFTP."
    }

    Log "$me completed"
    return 0
}
catch {
    Log $_.Exception.Message
    throw
}
