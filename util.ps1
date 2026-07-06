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

        return $dataSet.Tables[0]
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

        return $dataSet.Tables[0]
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

Function FormatCsvValue
{
    Param([object]$value)

    if ($null -eq $value -or $value -eq [System.DBNull]::Value) {
        return '""'
    }

    return '"' + ($value.ToString() -replace '"', '""') + '"'
}

Function SqlExportToCSV
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

        if ($reader.FieldCount -gt 0) {
            $header = @()

            for ($i = 0; $i -lt $reader.FieldCount; $i++) {
                $header += FormatCsvValue $reader.GetName($i)
            }

            $streamWriter.WriteLine([string]::Join(",", $header))
        }

        while ($reader.Read()) {
            $row = @()

            for ($i = 0; $i -lt $reader.FieldCount; $i++) {
                $row += FormatCsvValue $reader.GetValue($i)
            }

            $streamWriter.WriteLine([string]::Join(",", $row))
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

            $streamWriter.WriteLine("{0} [{1}] [{2}]" -f $loginOutDate, $userId, $action)
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

    $sftpProgram = Join-Path $common "sftp\psftp.exe"
    $dcsUtilRef = Join-Path $common "sftp\References\DcsUtils.dll"
    $sftpClient = $null

    try {
        Add-Type -Path $dcsUtilRef

        $sftpClient = New-Object DCS.Batch.Utils.SFTPClient($sftpProgram) -Property @{
            certPath = $certPath
            port = $port
            username = $userName
            hostname = $hostName
        }

        Log "SFTP> Upload $file to $hostName"
        return $sftpClient.Send($destination, $file)
    }
    catch {
        Log $_.Exception.Message
        return $false
    }
    finally {
        if ($null -ne $sftpClient) {
            $sftpClient.Dispose()
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

Function IsActiveJob
{
    Param([Parameter(Mandatory=$true)][string]$JobName)

    try {
        $status = GetBatchStatus $JobName
        $isOwner = IsJobOwner $JobName

        if ($isOwner -eq $true -and $status -ne "D" -and $status -ne "S") {
            return $true
        }

        return $false
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
        $escapedJobName = $JobName -replace "'", "''"
        $result = Sql "SELECT VAL FROM SYS_BATCH_PARM_VW WHERE JOB_NAME = '$escapedJobName' AND CTRL_KEY = 'JOB_OWNER'"

        if ($null -eq $result -or $result.Rows.Count -eq 0) {
            return $false
        }

        $owner = $result.Rows[0]["VAL"].ToString()

        if ($env:computername -eq $owner) {
            return $true
        }

        Log "Host not match. Host: $env:computername  Owner: $owner"
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
