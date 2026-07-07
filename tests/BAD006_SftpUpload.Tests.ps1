BeforeAll {
    $scriptRoot = Split-Path -Parent $PSScriptRoot
    $testLogDir = Join-Path $TestDrive 'bad006-test-logs'
    New-Item -ItemType Directory -Path $testLogDir -Force | Out-Null

    $global:logFile = Join-Path $testLogDir 'test.log'
    $global:connectionString = 'Server=localhost,1433;Database=DCDBDP;User Id=sa;Password=unused;TrustServerCertificate=True;'

    . (Join-Path $scriptRoot 'util.ps1')
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
