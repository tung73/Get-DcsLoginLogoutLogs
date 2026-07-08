# =============================================================================
# BAD006 - DCS Login/Logout Log Export
# Configuration for Get-DcsLoginLogoutLogs batch job.
#
# Paths are relative to $intfRoot unless an absolute path is specified.
# After a successful export, FromDate and ToDate are cleared
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
$BatchJobName = "BAD006"

# -----------------------------------------------------------------------------
# Directories
# -----------------------------------------------------------------------------

$LogDirectory = "$intfRoot\Log"
$WorkDirectory = "$intfRoot\Work"
$OutputDirectory = "\\uat.db.dcs.customs.hksarg\uat\iisroot\DcsEnqLog\out"
$SFTPBackupDirectory = "\\uat.db.dcs.customs.hksarg\uat\iisroot\DcsEnqLog\backup"

# Local folder scanned for files to upload via SFTP.
$SFTPSourceDirectory = "\\uat.db.dcs.customs.hksarg\uat\iisroot\DcsEnqLog\out"

# -----------------------------------------------------------------------------
# Export date range
# -----------------------------------------------------------------------------

# Inclusive export window (yyyy-MM-dd, e.g. 2026-06-04). Leave empty to skip
# TXT/ZIP generation while still running the SFTP upload step.
$FromDate = ""
$ToDate = ""

# -----------------------------------------------------------------------------
# Export filter
# -----------------------------------------------------------------------------

# USER_ID values matching this regex are excluded from the TXT export.
# Case-insensitive substring match. Leave empty to include all users.
$UserIdFilterRegex = "uat"

# -----------------------------------------------------------------------------
# SFTP upload
# -----------------------------------------------------------------------------

$SFTPProgram = "$intfRoot\sftp\psftp.exe"
$SFTPCert = "$intfRoot\sftp\dcs_to_itu4_uat_id_rsa.ppk"

# Optional psftp host key fingerprint. Leave empty to use the cached host key.
# Older psftp builds may not support -hostkey; in that case the job retries
# without -hostkey and uses the key cached for the Windows account running it.
$SFTPHostKey = ""

$SFTPHost = "sftplogsvruat.customs.hksarg"
$SFTPPort = "22"
$SFTPUser = "uat_sftp_log_dcs01"
$SFTPRemote = "/"
