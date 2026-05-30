BeforeAll {
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\New-DMObjectReport.ps1"
}

Describe 'New-DMObjectReport' {
    BeforeEach {
        $script:reportXml = @'
<hosts>
  <properties>
    <property><name>name</name><order>2</order><enabled>1</enabled></property>
    <property><name>id</name><order>1</order><enabled>1</enabled></property>
    <property><name>ignored</name><order>3</order><enabled>0</enabled></property>
  </properties>
</hosts>
'@
        $script:templatePath = Join-Path $TestDrive 'Report-Hosts.xml'
        Set-Content -LiteralPath $script:templatePath -Value $script:reportXml
        $script:HostsReportTemplate = $script:templatePath
        $script:hosts = @(
            [pscustomobject]@{ id = 'host-01'; name = 'alpha'; ignored = 'hidden' }
            [pscustomobject]@{ id = 'host-02'; name = 'beta'; ignored = 'hidden' }
        )
    }

    It 'creates report rows with enabled properties in template order' {
        $result = @(New-DMObjectReport -Object $script:hosts -ReportType hosts)

        $result.Count | Should -Be 2
        @($result[0].PSObject.Properties.Name) | Should -Be @('id', 'name')
        $result[0].id | Should -Be 'host-01'
        $result[1].name | Should -Be 'beta'
    }

    It 'uses a custom XML template when ReportTemplate is provided' {
        [xml]$customTemplate = @'
<hosts>
  <properties>
    <property><name>name</name><order>1</order><enabled>1</enabled></property>
  </properties>
</hosts>
'@

        $result = New-DMObjectReport -Object $script:hosts[0] -ReportType hosts -ReportTemplate $customTemplate

        @($result.PSObject.Properties.Name) | Should -Be @('name')
        $result.name | Should -Be 'alpha'
    }
}
