#*****************************************************************************
#
# File Name:           util.ps1
#
# Purpose:             Common functions for BAD006 batch job
#
#*****************************************************************************

$SqlPrintOutHandler = [System.Data.SqlClient.SqlInfoMessageEventHandler] {
    param($sqlSender, $sqlEvent)
    $null = $sqlSender
    Log "$sqlEvent"
}

Function Log
{
    Param([Parameter(Mandatory=$true)][string]$message)

    Add-Content $logFile -Value "[$("{0:yyyy-MM-dd HH:mm:ss}" -f (Get-Date))] $message"
    Write-Host "[$("{0:yyyy-MM-dd HH:mm:ss}" -f (Get-Date))] $message"
}

Function EnsureDirectory
{
    Param([Parameter(Mandatory=$true)][string]$path)

    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

Function ParseConfigDate
{
    Param(
        [Parameter(Mandatory=$true)][string]$dateText,
        [Parameter(Mandatory=$true)][string]$configName
    )

    $formats = [string[]]@("yyyyMMdd", "yyyy-MM-dd")
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $styles = [System.Globalization.DateTimeStyles]::None
    $parsedDate = [datetime]::MinValue

    if ([datetime]::TryParseExact($dateText, $formats, $culture, $styles, [ref]$parsedDate)) {
        return $parsedDate.Date
    }

    throw "$configName must be in yyyyMMdd or yyyy-MM-dd format. Current value: $dateText"
}

Function Sql
{
    Param(
        [Parameter(Mandatory=$true)][string]$sqlCommand,
        [bool]$LogSqlPrint = $true
    )

    $connection = $null

    try {
        $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)

        if ($LogSqlPrint) {
            $connection.add_InfoMessage($SqlPrintOutHandler)
        }

        $command = New-Object System.Data.SqlClient.SqlCommand($sqlCommand, $connection)
        $connection.Open()

        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $command
        $dataSet = New-Object System.Data.DataSet
        $adapter.Fill($dataSet) | Out-Null

        return ,$dataSet.Tables[0]
    }
    catch {
        Log $_.Exception.Message
        return $null
    }
    finally {
        if ($null -ne $connection) {
            $connection.Close()
        }
    }
}

Function SqlSP
{
    Param(
        [Parameter(Mandatory=$true)][string]$sqlCommand,
        [bool]$LogSqlPrint = $true,
        [System.Data.SqlClient.SqlParameter[]]$sqlParm = $null
    )

    $connection = $null

    try {
        $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)

        if ($LogSqlPrint) {
            $connection.add_InfoMessage($SqlPrintOutHandler)
        }

        $command = New-Object System.Data.SqlClient.SqlCommand($sqlCommand, $connection)

        if ($null -ne $sqlParm) {
            $command.Parameters.AddRange($sqlParm)
        }

        $command.CommandType = [System.Data.CommandType]::StoredProcedure
        $connection.Open()

        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $command
        $dataSet = New-Object System.Data.DataSet
        $adapter.Fill($dataSet) | Out-Null

        return ,$dataSet.Tables[0]
    }
    catch {
        Log $_.Exception.Message
        return $null
    }
    finally {
        if ($null -ne $connection) {
            $connection.Close()
        }
    }
}

Function SqlExportLoginOutText
{
    Param(
        [Parameter(Mandatory=$true)][string]$sqlCommand,
        [Parameter(Mandatory=$true)][string]$exportFileName,
        [bool]$LogSqlPrint = $true
    )

    $streamWriter = $null
    $connection = $null
    $reader = $null

    try {
        $streamWriter = New-Object System.IO.StreamWriter -ArgumentList $exportFileName, $false, ([System.Text.Encoding]::UTF8)
        $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)

        if ($LogSqlPrint) {
            $connection.add_InfoMessage($SqlPrintOutHandler)
        }

        $command = New-Object System.Data.SqlClient.SqlCommand($sqlCommand, $connection)
        $connection.Open()
        $reader = $command.ExecuteReader()

        $streamWriter.WriteLine("[Login/out date] [USER_ID] [Action]")

        while ($reader.Read()) {
            $loginOutDate = $reader.GetValue(0).ToString()
            $userId = $reader.GetValue(1).ToString()
            $action = $reader.GetValue(2).ToString()

            $streamWriter.WriteLine($loginOutDate + " [" + $userId + "] [" + $action + "]")
        }

        return 0
    }
    catch {
        Log $_.Exception.Message
        return 1
    }
    finally {
        if ($null -ne $reader) {
            $reader.Close()
        }

        if ($null -ne $connection) {
            $connection.Close()
        }

        if ($null -ne $streamWriter) {
            $streamWriter.Close()
        }
    }
}

Function ZipFiles
{
    Param(
        [Parameter(Mandatory=$true)][string[]]$source,
        [Parameter(Mandatory=$true)][string]$destination,
        [bool]$Append = $false
    )

    $archive = $null

    try {
        if (-not $Append -and (Test-Path $destination)) {
            Remove-Item $destination -Force
        }

        Add-Type -AssemblyName System.IO.Compression.FileSystem

        $archive = [System.IO.Compression.ZipFile]::Open($destination, "Update")
        $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal

        foreach ($file in $source) {
            if (-not (Test-Path $file)) {
                throw "Zip source file does not exist: $file"
            }

            $relative = Split-Path $file -Leaf
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file, $relative, $compressionLevel) | Out-Null
        }

        return 0
    }
    catch {
        Log $_.Exception.Message
        return 1
    }
    finally {
        if ($null -ne $archive) {
            $archive.Dispose()
        }
    }
}

Function New-SftpBatchFile
{
    Param(
        [Parameter(Mandatory=$true)][string]$destination,
        [Parameter(Mandatory=$true)][string]$file
    )

    $batchFile = Join-Path ([System.IO.Path]::GetTempPath()) ("bad006_sftp_{0}.txt" -f [Guid]::NewGuid().ToString())
    $commands = New-Object System.Collections.Generic.List[string]

    $remoteDirectory = $destination.Trim()

    if ($remoteDirectory -ne "" -and $remoteDirectory -ne "/") {
        $commands.Add("cd $remoteDirectory")
    }

    $commands.Add('put "' + $file.Replace('"', '""') + '"')
    $commands.Add("quit")
    $commands | Set-Content -Path $batchFile -Encoding ASCII

    return $batchFile
}

Function sFTPSend
{
    Param(
        [Parameter(Mandatory=$true)][string]$certPath,
        [Parameter(Mandatory=$true)][string]$port,
        [Parameter(Mandatory=$true)][string]$userName,
        [Parameter(Mandatory=$true)][string]$hostName,
        [Parameter(Mandatory=$true)][string]$destination,
        [Parameter(Mandatory=$true)][string]$file
    )

    $batchFile = $null

    try {
        if (-not (Test-Path $BAD006_SFTP_Program)) {
            throw "SFTP program not found: $BAD006_SFTP_Program"
        }

        if (-not (Test-Path $certPath)) {
            throw "SFTP certificate not found: $certPath"
        }

        if (-not (Test-Path $file)) {
            throw "SFTP upload file not found: $file"
        }

        $batchFile = New-SftpBatchFile $destination $file
        $target = "{0}@{1}" -f $userName, $hostName

        Log "SFTP> Upload $file to $hostName"

        $output = & $BAD006_SFTP_Program -batch -i $certPath -P $port $target -b $batchFile 2>&1
        $exitCode = $LASTEXITCODE

        if ($output) {
            Log "SFTP> $output"
        }

        if ($exitCode -ne 0) {
            Log "SFTP> Upload failed with exit code $exitCode"
            return $false
        }

        return $true
    }
    catch {
        Log $_.Exception.Message
        return $false
    }
    finally {
        if ($null -ne $batchFile -and (Test-Path $batchFile)) {
            Remove-Item $batchFile -Force
        }
    }
}

Function SendDirectoryBySFTP
{
    Param(
        [Parameter(Mandatory=$true)][string]$certPath,
        [Parameter(Mandatory=$true)][string]$port,
        [Parameter(Mandatory=$true)][string]$userName,
        [Parameter(Mandatory=$true)][string]$hostName,
        [Parameter(Mandatory=$true)][string]$destination,
        [Parameter(Mandatory=$true)][string]$sourceDirectory
    )

    $files = Get-ChildItem -Path $sourceDirectory -File

    if ($files.Count -eq 0) {
        Log "No files found in SFTP source directory: $sourceDirectory"
        return $true
    }

    $allSucceeded = $true

    foreach ($file in $files) {
        $result = sFTPSend $certPath $port $userName $hostName $destination $file.FullName

        if ($result -eq $true) {
            Log "Success upload: $($file.FullName)"
        }
        else {
            Log "Fail upload: $($file.FullName)"
            $allSucceeded = $false
        }
    }

    return $allSucceeded
}

Function Test-SqlResultHasRows
{
    Param($Result)

    if ($null -eq $Result) {
        return $false
    }

    if ($Result -is [System.Data.DataRow]) {
        return $true
    }

    if ($Result -is [System.Data.DataTable]) {
        return $Result.Select().Length -gt 0
    }

    return $false
}

Function Get-SqlResultScalar
{
    Param($Result)

    if ($null -eq $Result) {
        return $null
    }

    if ($Result -is [System.Data.DataRow]) {
        return $Result[0]
    }

    if ($Result -is [System.Data.DataTable]) {
        $rows = $Result.Select()

        if ($rows.Length -eq 0) {
            return $null
        }

        return $rows[0][0]
    }

    return $null
}

Function GetBatchParmValue
{
    Param(
        [Parameter(Mandatory=$true)][string]$JobName,
        [Parameter(Mandatory=$true)][string]$CtrlKey
    )

    $escapedJobName = $JobName -replace "'", "''"
    $escapedCtrlKey = $CtrlKey -replace "'", "''"
    $result = Sql "SELECT VAL FROM SYS_BATCH_PARM_VW WHERE JOB_NAME = '$escapedJobName' AND CTRL_KEY = '$escapedCtrlKey'" $false

    if (-not (Test-SqlResultHasRows $result)) {
        $result = Sql "SELECT VAL FROM SYS_BATCH_PARM_TBL WHERE JOB_NAME = '$escapedJobName' AND CTRL_KEY = '$escapedCtrlKey'" $false
    }

    if (-not (Test-SqlResultHasRows $result)) {
        Log "Batch parameter [$CtrlKey] not found for job [$JobName] in SYS_BATCH_PARM_VW or SYS_BATCH_PARM_TBL."
        return $null
    }

    $value = Get-SqlResultScalar $result

    if ($null -eq $value -or $value -eq [System.DBNull]::Value) {
        Log "Batch parameter [$CtrlKey] for job [$JobName] is empty."
        return $null
    }

    return $value.ToString().Trim()
}

Function Test-JobHostMatch
{
    Param([Parameter(Mandatory=$true)][string]$Owner)

    $hostName = $env:COMPUTERNAME

    if ([string]::Equals($hostName, $Owner, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    if ($Owner.StartsWith("$hostName.", [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    if ($hostName.StartsWith("$Owner.", [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    return $false
}

Function IsActiveJob
{
    Param([Parameter(Mandatory=$true)][string]$JobName)

    try {
        $enabled = GetBatchParmValue $JobName "ENABLE"

        if ($enabled -ne "Y") {
            Log "Job [$JobName] is not enabled. ENABLE=[$enabled]"
            return $false
        }

        $status = GetBatchStatus $JobName

        if ($status -eq "D" -or $status -eq "S") {
            Log "Job [$JobName] has inactive status [$status]."
            return $false
        }

        if (-not (IsJobOwner $JobName)) {
            return $false
        }

        return $true
    }
    catch {
        Log $_.Exception.Message
        return $null
    }
}

Function IsJobOwner
{
    Param([Parameter(Mandatory=$true)][string]$JobName)

    try {
        $owner = GetBatchParmValue $JobName "JOB_OWNER"

        if ($null -eq $owner) {
            return $false
        }

        if (Test-JobHostMatch $owner) {
            return $true
        }

        Log "Host not match. Host: $env:COMPUTERNAME  Owner: $owner"
        return $false
    }
    catch {
        Log $_.Exception.Message
        return $null
    }
}

Function GetBatchStatus
{
    Param([Parameter(Mandatory=$true)][string]$JobName)

    try {
        $sqlParam = New-Object System.Data.SqlClient.SqlParameter[] 2
        $sqlParam[0] = New-Object System.Data.SqlClient.SqlParameter("@JOB_NAME", "$JobName")
        $sqlParam[1] = New-Object System.Data.SqlClient.SqlParameter
        $sqlParam[1].ParameterName = "@STATUS"
        $sqlParam[1].SqlDbType = [System.Data.SqlDbType]::VarChar
        $sqlParam[1].Size = 50
        $sqlParam[1].Direction = [System.Data.ParameterDirection]::Output

        SqlSP "Batch_GetJobStatus" $true $sqlParam | Out-Null

        $returnValue = $sqlParam[1].Value
        Log "Batch job: $JobName with status: $returnValue"
        return $returnValue
    }
    catch {
        Log $_.Exception.Message
        return $null
    }
}
