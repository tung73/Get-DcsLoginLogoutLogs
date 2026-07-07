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

# Root folder for BAD006 batch directories (Log, Work, Out, Backup, SFTP).
$intfRoot = "O:\Batch"

# -----------------------------------------------------------------------------
# Database
# -----------------------------------------------------------------------------

# SQL Server connection string (Windows integrated security).
$connectionString = "Data Source=prd.db.dcs.customs.hksarg\DCINDP,11433;Initial Catalog=DCDBDP;Integrated Security=SSPI;"

# -----------------------------------------------------------------------------
# Job
# -----------------------------------------------------------------------------

# Batch job name used for SYS_BATCH_PARM lookup and logging.
$BAD006_JobName = "BAD006"

# -----------------------------------------------------------------------------
# Directories
# -----------------------------------------------------------------------------

$BAD006_LogDirectory = "$intfRoot\BAD006\Log"
$BAD006_WorkDirectory = "$intfRoot\BAD006\Work"
$BAD006_OutputDirectory = "$intfRoot\BAD006\Out"
$BAD006_SFTPBackupDirectory = "$intfRoot\BAD006\Backup"

# Local folder scanned for files to upload via SFTP (defaults to Output).
$BAD006_SFTPSourceDirectory = $BAD006_OutputDirectory

# -----------------------------------------------------------------------------
# Export date range
# -----------------------------------------------------------------------------

# Inclusive export window (yyyyMMdd or yyyy-MM-dd). Leave empty to skip
# TXT/ZIP generation while still running the SFTP upload step.
$BAD006_FromDate = "20260101"
$BAD006_ToDate = "20260301"

# -----------------------------------------------------------------------------
# Export filter
# -----------------------------------------------------------------------------

# USER_ID values matching this regex are excluded from the TXT export.
# Case-insensitive substring match. Leave empty to include all users.
$BAD006_UserIdFilterRegex = "uat"

# -----------------------------------------------------------------------------
# SFTP upload
# -----------------------------------------------------------------------------

$BAD006_SFTP_Program = "$intfRoot\BAD006\sftp\psftp.exe"
$BAD006_SFTP_Cert = "$intfRoot\BAD006\sftp\prd-dcs-to-scg-gcg.ppk"
$BAD006_SFTP_Host = "eservices.customs.hksarg"
$BAD006_SFTP_Port = "10023"
$BAD006_SFTP_User = "dcpxfr"
$BAD006_SFTP_Remote = "CTB/"
