#$connectionString = "Data Source=10.12.132.101\DCINDD;Initial Catalog=DCDBDD;Integrated Security=SSPI;"
#$connectionString = "Data Source=10.12.132.102\DCINDU;Initial Catalog=DCDBDU;Integrated Security=SSPI;"
$connectionString = "Data Source=prd.db.dcs.customs.hksarg\DCINDP,11433;Initial Catalog=DCDBDP;Integrated Security=SSPI;"
#$connectionString = "Server=10.12.132.101\DCINDD,11433;Database=DCDBDD;User Id=dcsadd01;Password=P@ssw0rd;"
$shareDrive = "\\prd.db.dcs.customs.hksarg\prd"

$batchRoot = "O:\Batch"
$intfRoot = "O:\Batch"

$emailExe = "O:\Batch\SendEmail\SendEmail.exe"
#$emailSupport = "johnny_kp_lam@customs.gov.hk, tony_ck_suen@customs.gov.hk"
$emailSupport = "victor_yt_lam@customs.gov.hk, walter_cw_cheong@customs.gov.hk, vincent_mc_chiu@customs.gov.hk"


$odcaRmEdi_adminLogDir = "$batchRoot\AdminLog\"
#$odcaRmEdi_API_IN_Folder = "$shareDrive\EdiHome\EBSY010\in"
$odcaRmEdi_API_IN_Folder = "$shareDrive\EdiHome\new"
$odcaRmEdi_API_OUT_Folder = "$shareDrive\EdiHome\apiOut"
$odcaRmEdi_EBIE010_Folder = "$batchRoot\EdiHome\EBIE010\"
$odcaRmEdi_EBSY040_Folder = "$batchRoot\EdiHome\EBSY040\"
$odcaRmEdi_EdiBackupFolder = "$shareDrive\EdiHome\Backup\"

$odcaRmEdi_batchLogDirList = @("$batchRoot\dcs_gen_rep\Log\",
                                "$batchRoot\dcs_gen_tx_log_rep\Log\",
                                "$batchRoot\dcs_purge_rep\Log\",
                                "$batchRoot\dcs_purge_tx_log\Log\",
                                "$batchRoot\dcs_purge_tx_log_rep\Log\",
                                #"$batchRoot\odca_cg_msg_count\Log\",
                                #"$batchRoot\odca_check_edi_app\Log\",
                                "$batchRoot\odca_daily_job\Log\",
                                "$batchRoot\odca_gen_rep\Log\",
                                "$batchRoot\odca_ob_gen_rep\Log\",
                                "$batchRoot\dcs_daily_job\Log\",
                                "$batchRoot\odca_rm_edi\Log\")   
                                
$odcaRmEdi_intfLogDirList = @("$intfRoot\EdiHome\EBSY010\Log\",
                                "$intfRoot\EdiHome\EBSY020\Log\",
                                "$intfRoot\EdiHome\EBSY030\Log\",                                    
                                "$intfRoot\EdiHome\EBSY050\Log\",                                                               
                                "$intfRoot\EdiHome\DCP_OUT\Log\",
                                "$intfRoot\EdiHome\odca_cg_msg_count\Log\", 
                                "$intfRoot\EdiHome\odca_check_edi_app\Log\",
                                "$intfRoot\ceis\Log\",
                                "$intfRoot\CUD_INTF\Log\",
                                "$intfRoot\EBEP020\bank_txn\LOG\",                                
                                "$intfRoot\EBEP020\bank_txn\LOG_ERROR\",
                                "$intfRoot\eman\BGR002\Log\",
                                "$intfRoot\GFMIS\Log\",
                                "$intfRoot\GFMIS\GFMIS\Client\Log\",
                                "$intfRoot\ROCARS\BPE005\Log\",
                                "$intfRoot\EdiHome\odca_rm_edi_intf\Log\")                                   

# 5 long running batch job
$odcaCheckEdiApp_BatchJobPath = @("$intfRoot\EdiHome\EBSY010\DcsBatchConsole.exe",
                                    "$intfRoot\EdiHome\EBSY020\DcsBatchConsole.exe",
                                    "$intfRoot\EdiHome\EBSY030\DcsBatchConsole.exe",
                                    #"$intfRoot\EdiHome\EBSY040\DcsBatchConsole.exe",
                                    "$intfRoot\EdiHome\EBSY050\DcsBatchConsole.exe")

$odcaCheckEdiApp_EdiHome = "$shareDrive\EdiHome"
$odcaCheckEdiApp_DataFile = "$odcaCheckEdiApp_EdiHome\in\DC*1.S*"

#$ccsPurgeRep_DCSReportLog = "S:\iisroot\Reports\Log"

$dcsPurgeTxnLog_dumpLogPath = "$batchRoot\dcs_purge_tx_log\oradump\tx_log\purge_tx_log_dump.log"
$dcsPurgeTxnLog_dumpLogZipFile = "$batchRoot\dcs_purge_tx_log\oradump\tx_log\purge_tx_log_dump.zip"

$generateReport_DebugMsg = $false
$generateReport_BatchSysUserId = "dcsdev01"
$generateReport_CCSReport = "S:\iisroot\Reports\Batch"
$generateReport_ReportDIR = "$shareDrive\iisroot\Reports\Batch"
$generateReport_PriLvl = "2"


$dcsGenRep_CCSReport = "$shareDrive\iisroot\Reports\Batch"
$dcsGenTxLogRep_CCSReport = "$shareDrive\iisroot\Reports\Batch"
$odcaGenRep_CCSReport = "$shareDrive\iisroot\Reports\Batch"
$odcaOBGenRep_CCSReport = "$shareDrive\iisroot\Reports\Batch"

$odcaDailyJob_CCSHome = "$batchRoot\odca_daily_job"

$odcaCGMsgCount_EDIHome = "$intfRoot\EdiHome"
$odcaCGMsgCount_EDIHome_InFile = "$shareDrive\EdiHome\in"
$odcaCGMsgCount_CCSLog = "$odcaCGMsgCount_EDIHome\odca_cg_msg_count\Log"
$odcaCGMsgCount_DailyRecon = "$odcaCGMsgCount_EDIHome\odca_cg_msg_count\DailyRecon"
$odcaCGMsgCount_DailyRecon_Backup = "$odcaCGMsgCount_EDIHome\odca_cg_msg_count\DailyRecon\Backup"
#$odcaCGMsgCount_DailyRecon_sFTP_Profile = "scgsftp"
$odcaCGMsgCount_DailyRecon_sFTP_Cert = "$odcaCGMsgCount_EDIHome\odca_cg_msg_count\sftp\prd-dcs-to-scg-gcg.ppk"
$odcaCGMsgCount_DailyRecon_sFTP_Port = "10023"
$odcaCGMsgCount_DailyRecon_sFTP_User = "dcpxfr"
$odcaCGMsgCount_DailyRecon_sFTP_Host = "eservices.customs.hksarg"
$odcaCGMsgCount_DailyRecon_sFTP_Remote = "CTB/"

$dcs_daily_job_dcs_purge_rep_script = "dcs_purge_rep\dcs_purge_rep.ps1"
$dcs_daily_job_dcs_purge_tx_log_rep_script = "dcs_purge_tx_log_rep\dcs_purge_tx_log_rep.ps1"
$dcs_daily_job_odca_gen_rep_script = "odca_gen_rep\odca_gen_rep.ps1"
$dcs_daily_job_odca_ob_gen_rep_script = "odca_ob_gen_rep\odca_ob_gen_rep.ps1"
$dcs_daily_job_dcs_gen_tx_log_rep_script = "dcs_gen_tx_log_rep\dcs_gen_tx_log_rep.ps1"
$dcs_daily_job_dcs_gen_rep_script = "dcs_gen_rep\dcs_gen_rep.ps1"
$dcs_daily_job_odca_daily_job_script = "odca_daily_job\odca_daily_job.ps1"
$dcs_daily_job_dcs_purge_tx_log_script = "dcs_purge_tx_log\dcs_purge_tx_log.ps1"

$copy_edi_in_msg_edi_in_folder = "O:\edi_in"
$copy_edi_in_msg_edi_in_share_folder = "$shareDrive\EdiHome\in"