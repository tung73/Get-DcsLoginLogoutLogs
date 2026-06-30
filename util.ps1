#*****************************************************************************
#
# File Name:		util.ps1
#
# Argument:             
#
# Purpose:           	common function for batch jobs
#
# Enviornment:		
#
# Author:       	Johnny
#
# Date:               	07/10/2015
#
# Function List:        
#
# Version:             	1.0 
#
# Admendment History
#
# Ref    Date           Author        Reason
#   1    2016-08-24     Johnny        add sFTP with cert
#   2    2016-11-15     Johnny        add IsActiveJob
#   3    2017-06-27     Johnny        add EventLog
#*****************************************************************************

$dateStamp = Get-Date -format ddMMyyyy
$dateStampReverse = Get-Date -format yyyyMMdd
$timeStamp = Get-Date -format HHmmss

$SqlPrintOutHandler = [System.Data.SqlClient.SqlInfoMessageEventHandler] {
        param($sender, $event)                 
        Log "$event"
    }

Function Log
{
    Param([Parameter(Mandatory=$true)][string]$message)
    
    #Add-content $logFile -value "[$([DateTime]::Now)]: $message"
    #Write-Host "[$([DateTime]::Now)]: $message"
    Add-content $logFile -value "[$("{0:yyyy-MM-dd HH:mm:ss}" -f (Get-Date))] $message"
    Write-Host "[$("{0:yyyy-MM-dd HH:mm:ss}" -f (Get-Date))] $message"
}

Function EventLog
{
    Param(
        [Parameter(Mandatory=$true)][string]$message,
        [string]$eventType = 'Error',
        [int]$eventId = 1
    )

    Write-EventLog -LogName Application -Source "DCS" -EntryType $eventType -EventId $eventId -Message "($me) - $message"
}

# Zip file list
Function ZipFiles
{
    Param( 
        [Parameter(Mandatory=$True)]
        [string[]]$source,
        [Parameter(Mandatory=$True)]
        [string]$destination,
        [bool]$Append = $FALSE
    ) #end param

    try
    {         
        if(!$Append) {
            If(Test-path $destination) {Remove-item $destination} 
        }
        Add-Type -assembly "system.io.compression.filesystem"                     
      
        $archive = [System.IO.Compression.ZipFile]::Open($destination, "Update")
        $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal              

        foreach($file in $source) {

            #$relative = (Resolve-Path $source -Relative).TrimStart(".\")
            $relative = Split-Path $file -Leaf        
            $null = [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,$file,$relative,$compressionlevel)

        }

        $archive.Dispose()        

        return 0

    } catch
    {
        Log $_.Exception.Message
        return 1
    }
}

# Zip directory
Function Zip
{
    Param( 
        [Parameter(Mandatory=$True)]
        [string]$source,
        [Parameter(Mandatory=$True)]
        [string]$destination
    ) #end param

    try
    { 
 
        If(Test-path $destination) {Remove-item $destination} 
        Add-Type -assembly "system.io.compression.filesystem" 
        [io.compression.zipfile]::CreateFromDirectory($Source, $destination) 
        return 0

    } catch
    {
        Log $_.Exception.Message
        return 1
    }
}

Function Sql {
    param(        
        [Parameter(Mandatory=$true)][string] $sqlCommand,
        [bool]$LogSqlPrint = $true
      )    
    try
    {
        $connection = new-object system.data.SqlClient.SQLConnection($connectionString)
        if ( $LogSqlPrint ) { $connection.add_InfoMessage($SqlPrintOutHandler) }
        $command = new-object system.data.sqlclient.sqlcommand($sqlCommand,$connection)
        $connection.Open()

        $adapter = New-Object System.Data.sqlclient.sqlDataAdapter $command
        $dataset = New-Object System.Data.DataSet
        $adapter.Fill($dataSet) | Out-Null

        $connection.Close()    
        
        return $dataSet.Tables[0]
    }catch
    {
        Log $_.Exception.Message
        return $null
    }
}

Function SqlSP {
    param(        
        [Parameter(Mandatory=$true)][string] $sqlCommand,
        [bool]$LogSqlPrint = $true,        
        [System.Data.SqlClient.SqlParameter[]] [ref]$sqlParm = $null
      )    
    try
    {
        $connection = new-object system.data.SqlClient.SQLConnection($connectionString)
        if ( $LogSqlPrint ) { $connection.add_InfoMessage($SqlPrintOutHandler) }
        $command = new-object system.data.sqlclient.sqlcommand($sqlCommand,$connection)
        if ( $sqlParm -ne $null )
        {                
            $command.Parameters.AddRange($sqlParm)        
        }
        $command.CommandType = [System.Data.CommandType]::StoredProcedure
        $connection.Open()

        $adapter = New-Object System.Data.sqlclient.sqlDataAdapter $command
        $dataset = New-Object System.Data.DataSet
        $adapter.Fill($dataSet) | Out-Null        

        $connection.Close()    
        
        return $dataSet.Tables[0]
    }catch
    {
        Log $_.Exception.Message
        return $null
    }
}

Function SqlFromFile {
    param(        
        [Parameter(Mandatory=$true)][string] $path,
        [bool]$LogSqlPrint = $true
      )    
    try
    {
        $sqlFile = Get-Content -path $path

        $sqlCommand = ""

        foreach($SQLString in  $sqlFile)
        {
            if($SQLString -ne "go") 
            {
                $sqlCommand += $SQLString + "`n"
            }
        }

        $connection = new-object system.data.SqlClient.SQLConnection($connectionString)
        if ( $LogSqlPrint ) { $connection.add_InfoMessage($SqlPrintOutHandler) }
        $command = new-object system.data.sqlclient.sqlcommand($sqlCommand,$connection)
        $connection.Open()

        $command.ExecuteNonQuery()

        $connection.Close()    
        
        return $true
    }catch
    {
        $ErrorMessage = $_.Exception.Message
        Log $ErrorMessage
        return $false
    }
}

Function SqlExportToText {
    param(        
        [Parameter(Mandatory=$true)][string] $sqlCommand,
        [Parameter(Mandatory=$true)][string] $exportFileName,
        [bool]$LogSqlPrint = $true
      )

    try
    {
        $streamWriter = New-Object System.IO.StreamWriter "$exportFileName"

        $connection = new-object system.data.SqlClient.SQLConnection($connectionString) 
        if ( $LogSqlPrint ) { $connection.add_InfoMessage($SqlPrintOutHandler) }        
        Log "Connection String> $connectionString"
        $command = new-object system.data.sqlclient.sqlcommand($sqlCommand,$connection)
        $connection.Open()

        $dr = $command.ExecuteReader()

        Do
        {    
            if ($dr.HasRows)
            {
                $array = @() 
                for ( $i = 0 ; $i -lt $dr.FieldCount; $i++ ) { $array += @($i) }                                
            
                while($dr.Read())
                {
                    $fieldCount = $dr.GetValues($array)
                    
                    for ($i = 0; $i -lt $array.Length; $i++) 
                    {                                                  
                        $array[$i] = $array[$i].ToString()
                    } 
                    
                    $newRow = [string]::Join($delimiter, $array)
                    
                    $streamWriter.WriteLine($newRow) 
                }

            }

        }while($dr.NextResult())
        
        $dr.Close()
        $connection.Close()    
        return 0

    } catch
    {
        Log $_.Exception.Message
        return 1
    }
    finally
    {
        if ($streamWriter -ne $null) {
            $streamWriter.Close()
        }
    }

}

Function SqlExportToCSV {
    param(        
        [Parameter(Mandatory=$true)][string] $sqlCommand,
        [Parameter(Mandatory=$true)][string] $exportFileName,
        [bool]$LogSqlPrint = $true
      )  
      
    try
    {  
      
        $delimiter = ","
        $streamWriter = New-Object System.IO.StreamWriter "$exportFileName"

        $connection = new-object system.data.SqlClient.SQLConnection($connectionString) 
        if ( $LogSqlPrint ) { $connection.add_InfoMessage($SqlPrintOutHandler) }        
        
        $command = new-object system.data.sqlclient.sqlcommand($sqlCommand,$connection)
        $connection.Open()

        $dr = $command.ExecuteReader()    
            
        Do
        {    
            if ($dr.HasRows)
            {
                $array = @() 
                for ( $i = 0 ; $i -lt $dr.FieldCount; $i++ ) { $array += @($i) }
                
                $streamWriter.Write('"' +$dr.GetName(0) + '"')
                for ( $i = 1; $i -lt $dr.FieldCount; $i ++) 
                {                     
                    $streamWriter.Write($("," + '"' + $dr.GetName($i) + '"')) 
                }
            
                while($dr.Read())
                {
                    $fieldCount = $dr.GetValues($array)
                    
                    for ($i = 0; $i -lt $array.Length; $i++) 
                    {                         
                        #if ($array[$i].ToString().Contains(",")) 
                        #{ 
                            $array[$i] = '"' + $array[$i].ToString() + '"'
                        #}                         
                    } 
                    
                    $newRow = [string]::Join($delimiter, $array)
                    
                    $streamWriter.WriteLine($newRow) 
                }    
            
            }
        }while($dr.NextResult())
        
        $dr.Close()
        $connection.Close()    
        return 0
    } catch
    {
        Log $_.Exception.Message
        return 1
    }
    finally
    {
        if ($streamWriter -ne $null) {
            $streamWriter.Close()
        }
    }
}

function addElement($e1, $name2, $value2, $attr2)
{        
    if ($e1.gettype().name -eq "XmlDocument") {
        $e2 = $e1.CreateElement($name2)
    } else {
        $e2 = $e1.ownerDocument.CreateElement($name2)
    }
    if ($attr2) {$e2.setAttribute($value2,$attr2)}
    elseif ($value2) {$e2.InnerText = "$value2"}
    return $e1.AppendChild($e2)
}

function validateXml {
    
    param (
    [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
        [string] $XmlFile,

        [Parameter(Mandatory=$true)]
        [string] $SchemaFile
    )

    [string[]]$Script:XmlValidationErrorLog = @()
    [scriptblock] $ValidationEventHandler = {
        $Script:XmlValidationErrorLog += $args[1].Exception.Message
    }

    try
    {

        $xml = New-Object System.Xml.XmlDocument
        $schemaReader = New-Object System.Xml.XmlTextReader $SchemaFile
        $schema = [System.Xml.Schema.XmlSchema]::Read($schemaReader, $ValidationEventHandler)
        $xml.Schemas.Add($schema) | Out-Null
        $xml.Load($XmlFile)
        $xml.Validate($ValidationEventHandler)    

        if ($Script:XmlValidationErrorLog) {
            Log "$($Script:XmlValidationErrorLog.Count) errors found"
            Log "$Script:XmlValidationErrorLog"
            return $null
        }
        else {        
            return $xml        
        }

    }
    catch
    {
        Log $_.Exception.Message
        return $null
    }
    finally
    {
        if ($schemaReader -ne $null) {
            $schemaReader.Close()
        }           
    }

}

function ExitWithCode 
{ 
    param 
    ( 
        $exitcode 
    ) 

    $host.SetShouldExit($exitcode)     
} 


Function sFTPSend
{    

    Param( 
        [Parameter(Mandatory=$True)]
        [string]$profile,
        [Parameter(Mandatory=$True)]
        [string]$destination,
        [Parameter(Mandatory=$True)]
        [string]$file
    )

    $sftpProgram = $common + "\sftp\psftp.exe"
    $dcsutilref = $common + "\sftp\References\DcsUtils.dll"

    Add-Type -Path $dcsutilref

    try
    {    

        $sftpClient = New-Object DCS.Batch.Utils.SFTPClient($sftpProgram) -Property @{
            profile = $profile            
        }
        
        Log "SFTP> Upload $file to $profile"            

        return $sftpClient.Send($destination,$file)

    }
    catch
    {
        Log $_.Exception.Message
        return $false
    }
    finally
    {
        $sftpClient.Dispose()
    }

}


Function sFTPSend
{    

    Param( 
        [Parameter(Mandatory=$True)]
        [string]$certPath,
        [Parameter(Mandatory=$True)]
        [string]$port,
        [Parameter(Mandatory=$True)]
        [string]$userName,
        [Parameter(Mandatory=$True)]
        [string]$hostName,
        [Parameter(Mandatory=$True)]
        [string]$destination,
        [Parameter(Mandatory=$True)]
        [string]$file
    )

    $sftpProgram = $common + "\sftp\psftp.exe"
    $dcsutilref = $common + "\sftp\References\DcsUtils.dll"

    Add-Type -Path $dcsutilref

    try
    {    

        $sftpClient = New-Object DCS.Batch.Utils.SFTPClient($sftpProgram) -Property @{
            certPath = $certPath
            port = $port
            username = $userName
            hostname = $hostName
        }
        
        Log "SFTP> Upload $file to $hostName"            

        return $sftpClient.Send($destination,$file)

    }
    catch
    {
        Log $_.Exception.Message
        return $false
    }
    finally
    {
        $sftpClient.Dispose()
    }

}



Function IsActiveJob
{
    Param( 
        [Parameter(Mandatory=$True)]
        [string]$JobName
        )

        try
        { 
            
            $sts = GetBatchStatus $JobName
            
            $IsOwner = IsJobOwner $JobName            
            
            if ($IsOwner -eq $true -and $sts -ne "D" -and $sts -ne "S") {
                return $true
            } else {
                return $false
            }            

        } catch
        {
            Log $_.Exception.Message
            return $null
        }
}

Function IsJobOwner
{
    Param( 
        [Parameter(Mandatory=$True)]
        [string]$JobName
        )

        try
        { 
            $result = Sql "SELECT VAL FROM SYS_BATCH_PARM_VW WHERE JOB_NAME = '$JobName' AND CTRL_KEY = 'JOB_OWNER'"

            if ($result -eq $null) { return $false }
            
            if ($env:computername -eq $result[0]) {
                return $true
            } else {
                Log "Host not match. Host: $env:computername  Owner: $($result[0])"
                return $false
            }            

        } catch
        {
            Log $_.Exception.Message
            return $null
        }
}

Function GetBatchStatus
{
    Param( 
        [Parameter(Mandatory=$True)]
        [string]$JobName
        )

        try
        {             
            $sParam = New-Object System.Data.SqlClient.SqlParameter[] 2
            $sParam[0] = New-Object System.Data.SqlClient.SqlParameter("@JOB_NAME","$JobName")
            $sParam[1] = New-Object System.Data.SqlClient.SqlParameter
            $sParam[1].ParameterName = "@STATUS"
            $sParam[1].SqlDbType = [System.Data.SqlDbType]::VarChar
            $sParam[1].Size = 50
            $sParam[1].Direction = [System.Data.ParameterDirection]::Output            
            SqlSP "Batch_GetJobStatus" $true ([ref]$sParam)            

            $rtnVal = $sParam[1].Value            
            
            Log "Batch job: $JobName with status: $rtnVal"            
            return $rtnVal

        } catch
        {
            Log $_.Exception.Message
            return $null
        }
}