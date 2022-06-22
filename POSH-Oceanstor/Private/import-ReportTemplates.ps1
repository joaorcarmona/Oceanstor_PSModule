#Get Script RootPath
$workDir = $(get-item $PSScriptRoot).Parent.FullName

#Locattion for Lun Report Template
$global:Lunsv3ReportTemplate  = $workDir + "/Templates/Report-Lunsv3.xml"
$global:Lunsv6ReportTemplate  = $workDir + "/Templates/Report-Lunsv6.xml"
$global:HostsReportTemplate  = $workDir + "/Templates/Report-Hosts.xml"
$global:HostGroupsReportTemplate  = $workDir + "/Templates/Report-HostGroups.xml"
$global:LunGroupsReportTemplate  = $workDir + "/Templates/Report-LunGroups.xml"
$global:DisksReportTemplate  = $workDir + "/Templates/Report-Disks.xml"

