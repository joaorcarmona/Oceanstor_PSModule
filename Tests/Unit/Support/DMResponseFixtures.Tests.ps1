BeforeAll {
    . "$PSScriptRoot\DMResponseFixtures.ps1"
}

Describe 'New-DMFixtureSuccessResponse' {
    It 'defaults to error.Code 0 and no data property' {
        $response = New-DMFixtureSuccessResponse

        $response.error.Code | Should -Be 0
        $response.PSObject.Properties.Name | Should -Not -Contain 'data'
    }

    It 'attaches the data property only when -Data is bound' {
        $response = New-DMFixtureSuccessResponse -Data @('a', 'b')

        $response.data | Should -Be @('a', 'b')
    }
}

Describe 'New-DMFixtureErrorResponse' {
    It 'round-trips a non-zero Code and Description' {
        $response = New-DMFixtureErrorResponse -Code 50331651 -Description 'entered parameter is incorrect'

        $response.error.Code | Should -Be 50331651
        $response.error.description | Should -Be 'entered parameter is incorrect'
    }
}

Describe 'New-DMFixtureSessionExpiredResponse' {
    It 'uses the canonical session-expired code and description' {
        $response = New-DMFixtureSessionExpiredResponse

        $response.error.Code | Should -Be 1077939726
        $response.error.description | Should -Be 'session expired'
    }
}

Describe 'New-DMFixtureEmptyResponse' {
    It 'returns error.Code 0 with an empty data array' {
        $response = New-DMFixtureEmptyResponse

        $response.error.Code | Should -Be 0
        $response.data.Count | Should -Be 0
    }
}

Describe 'New-DMFixturePagedResponse' {
    It 'slices an exclusive-end window matching Invoke-DMPagedRequest semantics' {
        $items = 0..9

        $response = New-DMFixturePagedResponse -Items $items -Start 2 -End 5

        $response.data | Should -Be @(2, 3, 4)
    }

    It 'returns an empty page when Start is beyond the available items' {
        $response = New-DMFixturePagedResponse -Items @(1, 2, 3) -Start 10 -End 20

        $response.data.Count | Should -Be 0
    }
}

Describe 'New-DMFixtureIdenticalPageResponse' {
    It 'returns the same full page contents on repeated calls' {
        $items = @('x', 'y', 'z')

        $first = New-DMFixtureIdenticalPageResponse -Items $items
        $second = New-DMFixtureIdenticalPageResponse -Items $items

        $first.data | Should -Be $second.data
        $first.data | Should -Be $items
    }
}

Describe 'Fixture sample objects' {
    It 'New-DMFixtureLun uses sanitized default values' {
        $lun = New-DMFixtureLun

        $lun.ID | Should -Be 'POSHTEST-LUN01'
        $lun.WWN | Should -Be '2100000000000000'
    }

    It 'New-DMFixtureHost uses sanitized default values' {
        $dmHost = New-DMFixtureHost

        $dmHost.ID | Should -Be 'POSHTEST-HOST01'
        $dmHost.INITIATORIQN | Should -Be 'iqn.1993-08.org.debian:01:poshtest'
    }

    It 'New-DMFixtureFileSystem uses sanitized default values' {
        $fs = New-DMFixtureFileSystem

        $fs.ID | Should -Be 'POSHTEST-FS01'
    }

    It 'New-DMFixtureNetworkObject uses a TEST-NET-1 (RFC 5737) address' {
        $lif = New-DMFixtureNetworkObject

        $lif.IPV4ADDR | Should -Be '192.0.2.10'
    }

    It 'New-DMFixtureReplicationObject uses sanitized default values' {
        $pair = New-DMFixtureReplicationObject

        $pair.LOCALRESID | Should -Be 'POSHTEST-LUN01'
        $pair.REMOTERESID | Should -Be 'POSHTEST-LUN02'
    }
}

Describe 'Resource-string helpers' {
    It 'New-DMExactFilterResource builds a double-colon filter pattern' {
        New-DMExactFilterResource -Resource 'lun' -Property 'ID' -Value 'poshtest-lun' |
            Should -BeLike 'lun?filter=ID::poshtest-lun*'
    }

    It 'New-DMFuzzyFilterResource builds a single-colon filter pattern' {
        New-DMFuzzyFilterResource -Resource 'lun' -Property 'NAME' -Value 'poshtest' |
            Should -BeLike 'lun?filter=NAME:poshtest*'
    }

    It 'New-DMRangeResourcePattern uses a leading ? when the resource has no query string yet' {
        New-DMRangeResourcePattern -Resource 'lun' -Start 0 -End 100 |
            Should -BeLike 'lun?range=`[0-100`]*'
    }

    It 'New-DMRangeResourcePattern uses & when the resource already has a query string' {
        New-DMRangeResourcePattern -Resource 'lun?filter=NAME:poshtest*' -Start 0 -End 100 |
            Should -BeLike 'lun?filter=NAME:poshtest*&range=`[0-100`]*'
    }
}

Describe 'Sanitization' {
    It 'never emits the real lab IP address from any fixture builder' {
        $rendered = @(
            (New-DMFixtureSuccessResponse -Data 'x' | Out-String)
            (New-DMFixtureErrorResponse -Code 1 -Description 'x' | Out-String)
            (New-DMFixtureSessionExpiredResponse | Out-String)
            (New-DMFixtureEmptyResponse | Out-String)
            (New-DMFixtureLun | Out-String)
            (New-DMFixtureHost | Out-String)
            (New-DMFixtureFileSystem | Out-String)
            (New-DMFixtureNetworkObject | Out-String)
            (New-DMFixtureReplicationObject | Out-String)
        ) -join "`n"

        $rendered | Should -Not -Match '10\.10\.10\.24'
    }
}
