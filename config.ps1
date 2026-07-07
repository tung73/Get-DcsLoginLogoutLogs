# =============================================================================
# BAD006 - DCS Login/Logout Log Export
# Configuration for Get-DcsLoginLogoutLogs batch job.
#
# Paths are relative to $intfRoot unless an absolute path is specified.
# After a successful export, BAD006_FromDate and BAD006_ToDate are cleared
# automatically by the job script.
# =============================================================================

# -----------------------------------------------------------------------------
# Environment
# -----------------------------------------------------------------------------

# Root folder for BAD006 local directories (Log, Work, SFTP client).
$intfRoot = "O:\Batch\BAD006"

# -----------------------------------------------------------------------------
# Database
# -----------------------------------------------------------------------------

# SQL Server connection string (Windows integrated security).
$connectionString = "Data Source=uat.db.dcs.customs.hksarg\DCINDU;Initial Catalog=DCDBDU;Integrated Security=SSPI;"

# -----------------------------------------------------------------------------
# Job
# -----------------------------------------------------------------------------

# Batch job name used for SYS_BATCH_PARM lookup and logging.
$BAD006_JobName = "BAD006"

# -----------------------------------------------------------------------------
# Directories
# -----------------------------------------------------------------------------

$BAD006_LogDirectory = "$intfRoot\Log"
$BAD006_WorkDirectory = "$intfRoot\Work"
$BAD006_OutputDirectory = "\\uat.db.dcs.customs.hksarg\uat\iisroot\DcsEnqLog\out"
$BAD006_SFTPBackupDirectory = "\\uat.db.dcs.customs.hksarg\uat\iisroot\DcsEnqLog\backup"

# Local folder scanned for files to upload via SFTP.
$BAD006_SFTPSourceDirectory = "\\uat.db.dcs.customs.hksarg\uat\iisroot\DcsEnqLog\out"

# -----------------------------------------------------------------------------
# Export date range
# -----------------------------------------------------------------------------

# Inclusive export window (yyyy-MM-dd, e.g. 2026-06-04). Leave empty to skip
# TXT/ZIP generation while still running the SFTP upload step.
$BAD006_FromDate = ""
$BAD006_ToDate = ""

# -----------------------------------------------------------------------------
# Export filter
# -----------------------------------------------------------------------------

# USER_ID values matching this regex are excluded from the TXT export.
# Case-insensitive substring match. Leave empty to include all users.
$BAD006_UserIdFilterRegex = "uat"

# -----------------------------------------------------------------------------
# SFTP upload
# -----------------------------------------------------------------------------

$BAD006_SFTP_Program = "$intfRoot\sftp\psftp.exe"
$BAD006_SFTP_Cert = "$intfRoot\sftp\dcs_to_itu4_uat_id_rsa.ppk"
$BAD006_SFTP_Host = "sftplogsvruat.customs.hksarg"
$BAD006_SFTP_Port = "22"
$BAD006_SFTP_User = "uat_sftp_log_dcs01"
$BAD006_SFTP_Remote = "/"
