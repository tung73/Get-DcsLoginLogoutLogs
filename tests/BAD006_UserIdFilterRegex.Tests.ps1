BeforeAll {
    $scriptRoot = Split-Path -Parent $PSScriptRoot
    $testLogDir = Join-Path $TestDrive 'bad006-test-logs'
    New-Item -ItemType Directory -Path $testLogDir -Force | Out-Null

    $global:logFile = Join-Path $testLogDir 'test.log'
    $global:connectionString = 'Server=localhost,1433;Database=DCDBDP;User Id=sa;Password=unused;TrustServerCertificate=True;'

    . (Join-Path $scriptRoot 'util.ps1')
}

Describe 'Test-UserIdExcludedByRegex' {
    Context 'default UserIdFilterRegex value (uat)' {
        It 'excludes user IDs containing uat (case-insensitive)' {
            Test-UserIdExcludedByRegex 'UserUAT01' 'uat' | Should -Be $true
            Test-UserIdExcludedByRegex 'USERUAT' 'uat' | Should -Be $true
            Test-UserIdExcludedByRegex 'uat_user' 'uat' | Should -Be $true
            Test-UserIdExcludedByRegex 'UserUat01' 'uat' | Should -Be $true
        }

        It 'does not exclude user IDs without uat substring' {
            Test-UserIdExcludedByRegex 'UserA' 'uat' | Should -Be $false
            Test-UserIdExcludedByRegex 'production_user' 'uat' | Should -Be $false
            Test-UserIdExcludedByRegex 'admin' 'uat' | Should -Be $false
        }
    }

    Context 'config.ps1 default UserIdFilterRegex' {
        It 'uses the configured default to exclude uat user IDs' {
            $configPath = Join-Path $scriptRoot 'config.ps1'
            $configLine = Select-String -Path $configPath -Pattern '^\$UserIdFilterRegex\s*=\s*"([^"]*)"' |
                Select-Object -First 1

            $configLine | Should -Not -BeNullOrEmpty
            $configRegex = $configLine.Matches[0].Groups[1].Value

            Test-UserIdExcludedByRegex 'UserUAT01' $configRegex | Should -Be $true
            Test-UserIdExcludedByRegex 'production_user' $configRegex | Should -Be $false
        }
    }

    Context 'empty or whitespace regex (no filtering)' {
        It 'never excludes when regex is empty' {
            Test-UserIdExcludedByRegex 'UserUAT01' '' | Should -Be $false
            Test-UserIdExcludedByRegex 'production_user' '' | Should -Be $false
        }

        It 'never excludes when regex is whitespace only' {
            Test-UserIdExcludedByRegex 'UserUAT01' '   ' | Should -Be $false
        }
    }

    Context 'custom regex patterns' {
        It 'supports anchored patterns' {
            Test-UserIdExcludedByRegex 'testuser' '^test' | Should -Be $true
            Test-UserIdExcludedByRegex 'usertest' '^test' | Should -Be $false
        }

        It 'supports alternation' {
            Test-UserIdExcludedByRegex 'demo01' 'uat|demo' | Should -Be $true
            Test-UserIdExcludedByRegex 'UserUAT01' 'uat|demo' | Should -Be $true
            Test-UserIdExcludedByRegex 'prod01' 'uat|demo' | Should -Be $false
        }

        It 'supports prefix-only match' {
            Test-UserIdExcludedByRegex 'uat01' '^uat' | Should -Be $true
            Test-UserIdExcludedByRegex 'myuat' '^uat' | Should -Be $false
        }
    }

    Context 'edge cases' {
        It 'does not exclude whitespace-only user ID for uat regex' {
            Test-UserIdExcludedByRegex '   ' 'uat' | Should -Be $false
        }
    }
}

Describe 'SqlExportLoginOutText regex validation' {
    It 'returns 1 when UserIdFilterRegex is invalid' {
        $exportPath = Join-Path $TestDrive 'invalid-regex-export.txt'

        $result = SqlExportLoginOutText 'SELECT 1' $exportPath $false '[invalid('

        $result | Should -Be 1
    }

    It 'rejects invalid regex without requiring a reachable SQL Server' {
        $exportPath = Join-Path $TestDrive 'invalid-regex-export-2.txt'
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        $result = SqlExportLoginOutText 'SELECT 1' $exportPath $false '(['

        $stopwatch.Stop()
        $result | Should -Be 1
        $stopwatch.Elapsed.TotalSeconds | Should -BeLessThan 5
    }
}
