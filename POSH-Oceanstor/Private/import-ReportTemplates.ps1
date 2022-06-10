#Get Script RootPath
$workDir = $(get-item $PSScriptRoot).Parent.FullName

#Locattion for Lun Report Template
$global:LunsReportTemplate  = $workDir + "/Templates/Report-Luns.xml"
