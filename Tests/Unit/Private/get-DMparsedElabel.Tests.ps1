BeforeAll {
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\get-DMparsedElabel.ps1"
}

Describe 'get-DMparsedElabel' {
    It 'returns supported label values from line-feed separated input' {
        $eLabelString = @(
            'BoardType=Disk'
            'BarCode=BC123456'
            'VendorName=Huawei'
            'Unsupported=ignored'
        ) -join "`n"

        $result = get-DMparsedElabel -eLabelString $eLabelString

        $result['BoardType'] | Should -Be 'Disk'
        $result['BarCode'] | Should -Be 'BC123456'
        $result['VendorName'] | Should -Be 'Huawei'
        $result.ContainsKey('Unsupported') | Should -BeFalse
    }

    It 'parses carriage-return line-feed separated input without retaining carriage returns' {
        $eLabelString = @(
            'Model=OceanStor'
            'IssueNumber=01'
        ) -join "`r`n"

        $result = get-DMparsedElabel -eLabelString $eLabelString

        $result['Model'] | Should -Be 'OceanStor'
        $result['IssueNumber'] | Should -Be '01'
    }

    It 'accepts the label input from the pipeline' {
        $result = 'Description=System disk' | get-DMparsedElabel

        $result['Description'] | Should -Be 'System disk'
    }
}
