BeforeAll {
    $scriptRoot = Split-Path -Parent $PSScriptRoot
    $testLogDir = Join-Path $TestDrive 'bad006-test-logs'
    New-Item -ItemType Directory -Path $testLogDir -Force | Out-Null

    $global:logFile = Join-Path $testLogDir 'test.log'
    $global:connectionString = 'Server=localhost,1433;Database=DCDBDP;User Id=sa;Password=unused;TrustServerCertificate=True;'

    . (Join-Path $scriptRoot 'util.ps1')
}

Describe 'Invoke-Psftp' {
    It 'captures native command output and non-zero exit code without throwing' {
        $originalProgram = $global:BAD006_SFTP_Program
        $originalNativePreference = $PSNativeCommandUseErrorActionPreference

        try {
            $global:BAD006_SFTP_Program = 'pwsh'
            $PSNativeCommandUseErrorActionPreference = $true

            $result = Invoke-Psftp -arguments @('-NoProfile', '-Command', 'Write-Output "Using username `"uat_sftp_log_dcs01`"."; exit 2')

            $result.ExitCode | Should -Be 2
            $result.OutputText | Should -Match 'Using username'
            $PSNativeCommandUseErrorActionPreference | Should -Be $true
        }
        finally {
            $global:BAD006_SFTP_Program = $originalProgram
            $PSNativeCommandUseErrorActionPreference = $originalNativePreference
        }
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
