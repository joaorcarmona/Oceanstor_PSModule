BeforeAll {
    function global:Invoke-DeviceManager {
        param(
            [pscustomobject]$WebSession,
            [string]$Method,
            [string]$Resource
        )
    }

    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\Invoke-DMPagedRequest.ps1"
}

AfterAll {
    Remove-Item -LiteralPath 'Function:\global:Invoke-DeviceManager' -ErrorAction SilentlyContinue
    Remove-Variable -Name PagedCalls -Scope Global -ErrorAction SilentlyContinue
}

Describe 'Invoke-DMPagedRequest' {
    BeforeEach {
        $script:session = [pscustomobject]@{ hostname = 'array01' }
    }

    It 'returns all items from a single page when the collection is smaller than PageSize' {
        Mock Invoke-DeviceManager {
            [pscustomobject]@{ data = @(
                [pscustomobject]@{ Id = '1' }
                [pscustomobject]@{ Id = '2' }
            )}
        }

        $result = Invoke-DMPagedRequest -WebSession $script:session -Resource 'lun'

        $result.Count | Should -Be 2
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly
    }

    It 'requests subsequent pages when the first page is full' {
        $script:callCount = 0
        Mock Invoke-DeviceManager {
            $script:callCount++
            if ($script:callCount -eq 1) {
                [pscustomobject]@{ data = 1..100 | ForEach-Object { [pscustomobject]@{ Id = "$_" } } }
            }
            else {
                [pscustomobject]@{ data = @([pscustomobject]@{ Id = '101' }) }
            }
        }

        $result = Invoke-DMPagedRequest -WebSession $script:session -Resource 'lun'

        $result.Count | Should -Be 101
        Should -Invoke Invoke-DeviceManager -Times 2 -Exactly
    }

    It 'appends range with ? when resource has no existing query parameters' {
        $script:capturedResource = $null
        Mock Invoke-DeviceManager {
            $script:capturedResource = $Resource
            [pscustomobject]@{ data = @() }
        }

        Invoke-DMPagedRequest -WebSession $script:session -Resource 'lun'

        $script:capturedResource | Should -BeLike 'lun?range=*'
    }

    It 'appends range with & when resource already has query parameters' {
        $script:capturedResource = $null
        Mock Invoke-DeviceManager {
            $script:capturedResource = $Resource
            [pscustomobject]@{ data = @() }
        }

        Invoke-DMPagedRequest -WebSession $script:session -Resource 'snapshot?filter=SOURCELUNID:42'

        $script:capturedResource | Should -BeLike 'snapshot?filter=SOURCELUNID:42&range=*'
    }

    It 'requests the correct range on each page' {
        $global:PagedCalls = [System.Collections.Generic.List[string]]::new()
        Mock Invoke-DeviceManager {
            $global:PagedCalls.Add($Resource)
            if ($global:PagedCalls.Count -eq 1) {
                [pscustomobject]@{ data = 1..100 | ForEach-Object { [pscustomobject]@{ Id = "$_" } } }
            }
            else {
                [pscustomobject]@{ data = @() }
            }
        }

        Invoke-DMPagedRequest -WebSession $script:session -Resource 'lun' -PageSize 100

        $global:PagedCalls[0] | Should -Be 'lun?range=[0,99]'
        $global:PagedCalls[1] | Should -Be 'lun?range=[100,199]'
    }

    It 'returns an empty array when the collection is empty' {
        Mock Invoke-DeviceManager {
            [pscustomobject]@{ data = @() }
        }

        $result = Invoke-DMPagedRequest -WebSession $script:session -Resource 'lun'

        $result.Count | Should -Be 0
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly
    }
}
