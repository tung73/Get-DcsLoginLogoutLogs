BeforeAll {
    $scriptRoot = Split-Path -Parent $PSScriptRoot
    $testLogDir = Join-Path $TestDrive 'bad006-test-logs'
    New-Item -ItemType Directory -Path $testLogDir -Force | Out-Null

    $global:logFile = Join-Path $testLogDir 'test.log'
    $global:connectionString = 'Server=localhost,1433;Database=DCDBDP;User Id=sa;Password=unused;TrustServerCertificate=True;'

    . (Join-Path $scriptRoot 'util.ps1')
}

Describe 'Log' {
    It 'writes INFO level by default' {
        $global:logFile = Join-Path $TestDrive 'default-level.log'

        Log 'default level message'

        Get-Content -Path $global:logFile | Select-Object -Last 1 | Should -Match '^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] \[INFO\] default level message$'
    }

    It 'writes explicit ERROR level' {
        $global:logFile = Join-Path $TestDrive 'explicit-level.log'

        Log 'explicit level message' 'ERROR'

        Get-Content -Path $global:logFile | Select-Object -Last 1 | Should -Match '^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] \[ERROR\] explicit level message$'
    }
}

Describe 'Invoke-Psftp' {
    It 'captures native command output and non-zero exit code without throwing' {
        $originalProgram = $global:SFTPProgram
        $originalNativePreference = $PSNativeCommandUseErrorActionPreference
        $originalErrorActionPreference = $ErrorActionPreference

        try {
            $global:SFTPProgram = 'pwsh'
            $ErrorActionPreference = 'Stop'
            $PSNativeCommandUseErrorActionPreference = $true

            $result = Invoke-Psftp -arguments @('-NoProfile', '-Command', '[Console]::Error.WriteLine("Using username `"uat_sftp_log_dcs01`"."); exit 2')

            $result.ExitCode | Should -Be 2
            $result.OutputText | Should -Match 'Using username'
            $PSNativeCommandUseErrorActionPreference | Should -Be $true
            $ErrorActionPreference | Should -Be 'Stop'
        }
        finally {
            $global:SFTPProgram = $originalProgram
            $PSNativeCommandUseErrorActionPreference = $originalNativePreference
            $ErrorActionPreference = $originalErrorActionPreference
        }
    }
}

Describe 'New-PsftpArguments' {
    It 'builds psftp arguments without host key when host key is blank' {
        $args = New-PsftpArguments 'cert.ppk' '22' 'user@example.test' 'batch.txt' ''

        $args | Should -Be @('-batch', '-P', '22', '-i', 'cert.ppk', 'user@example.test', '-b', 'batch.txt')
    }

    It 'includes host key argument when configured' {
        $args = New-PsftpArguments 'cert.ppk' '22' 'user@example.test' 'batch.txt' 'ssh-rsa 2048 SHA256:abc'

        $args | Should -Be @('-batch', '-hostkey', 'ssh-rsa 2048 SHA256:abc', '-P', '22', '-i', 'cert.ppk', 'user@example.test', '-b', 'batch.txt')
    }
}

Describe 'Test-PsftpHostKeyOptionUnsupported' {
    It 'detects older psftp builds that do not support -hostkey' {
        $output = @'
psftp: unknown option "-hostkey"
       try typing "psftp -h" for help
'@

        Test-PsftpHostKeyOptionUnsupported $output | Should -Be $true
    }

    It 'does not match unrelated psftp output' {
        Test-PsftpHostKeyOptionUnsupported 'Using username "uat_sftp_log_dcs01".' | Should -Be $false
    }
}

Describe 'Test-SftpPutSucceeded' {
    It 'treats psftp transfer log as success even when exit code is non-zero' {
        $output = @'
Using username "uat_sftp_log_dcs01".
Remote working directory: /
psftp> put "\\uat.db.dcs.customs.hksarg\uat\iisroot\DcsEnqLog\out\DCS_LOGIN_20260101_to_20261231_20260707092518.zip"
local:\\uat.db.dcs.customs.hksarg\uat\iisroot\DcsEnqLog\out\DCS_LOGIN_20260101_to_20261231_20260707092518.zip => remote:/DCS_LOGIN_20260101_to_20261231_20260707092518.zip
psftp> quit
'@

        Test-SftpPutSucceeded $output 2 | Should -Be $true
    }

    It 'accepts exit code 0 without transfer log line' {
        Test-SftpPutSucceeded '' 0 | Should -Be $true
    }

    It 'rejects authentication failure' {
        $output = 'FATAL ERROR: Authentication failed'

        Test-SftpPutSucceeded $output 1 | Should -Be $false
    }

    It 'rejects permission denied without transfer log line' {
        $output = 'remote /: permission denied'

        Test-SftpPutSucceeded $output 2 | Should -Be $false
    }

    It 'rejects non-zero exit code when transfer log line is missing' {
        $output = 'psftp> quit'

        Test-SftpPutSucceeded $output 2 | Should -Be $false
    }
}

Describe 'Test-SftpRemoteListingContainsFile' {
    It 'accepts a server-renamed .zip.enc.zip file in the remote listing' {
        $fileName = 'DCS_LOGIN_20260101_to_20260201_20260707093759.zip'
        $output = @'
Using username "uat_sftp_log_dcs01".
Remote working directory: /
-rw-rw----   1 no-user  no-group     3538 Jul  7 01:37 DCS_LOGIN_20260101_to_20260201_20260707093759.zip.enc.zip
'@

        Test-SftpRemoteListingContainsFile $output $fileName | Should -Be $true
    }

    It 'rejects output that only shows successful login without a matching file' {
        $fileName = 'DCS_LOGIN_20260101_to_20260201_20260707093759.zip'
        $output = 'Using username "uat_sftp_log_dcs01".'

        Test-SftpRemoteListingContainsFile $output $fileName | Should -Be $false
    }

    It 'rejects authentication failure during remote verification' {
        $fileName = 'DCS_LOGIN_20260101_to_20260201_20260707093759.zip'
        $output = 'FATAL ERROR: Authentication failed'

        Test-SftpRemoteListingContainsFile $output $fileName | Should -Be $false
    }
}
