Describe 'Import-ReportTemplates.ps1' {
    AfterEach {
        @(
            'Lunsv3ReportTemplate'
            'Lunsv6ReportTemplate'
            'HostsReportTemplate'
            'HostGroupsReportTemplate'
            'LunGroupsReportTemplate'
            'DisksReportTemplate'
        ) | ForEach-Object {
            Remove-Variable -Name $_ -Scope Global -ErrorAction SilentlyContinue
        }
    }

    It 'sets the default report template paths' {
        . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\Import-ReportTemplates.ps1"

        $global:Lunsv3ReportTemplate | Should -Match 'Templates[/\\]Report-Lunsv3\.xml$'
        $global:Lunsv6ReportTemplate | Should -Match 'Templates[/\\]Report-Lunsv6\.xml$'
        $global:HostsReportTemplate | Should -Match 'Templates[/\\]Report-Hosts\.xml$'
        $global:HostGroupsReportTemplate | Should -Match 'Templates[/\\]Report-HostGroups\.xml$'
        $global:LunGroupsReportTemplate | Should -Match 'Templates[/\\]Report-LunGroups\.xml$'
        $global:DisksReportTemplate | Should -Match 'Templates[/\\]Report-Disks\.xml$'

        @(
            $global:Lunsv3ReportTemplate
            $global:Lunsv6ReportTemplate
            $global:HostsReportTemplate
            $global:HostGroupsReportTemplate
            $global:LunGroupsReportTemplate
            $global:DisksReportTemplate
        ) | ForEach-Object {
            $_ | Should -Exist
        }
    }
}
