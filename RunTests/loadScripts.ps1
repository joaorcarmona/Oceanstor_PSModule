
$workDir = $(get-item $PSScriptRoot).Parent.FullName
[array] $ModulesToLoad = @(
    [pscustomobject]@{ModuleName="OceanStorPSModuleClass";Location="$workDir\Main\OceanStorPSModuleClass.ps1"}
    [pscustomobject]@{ModuleName="OceanStorPSModuleBase";Location="$workDir\Main\OceanStorPSModuleBase.ps1"}
    [pscustomobject]@{ModuleName="OceanStorPSModuleSys";Location="$workDir\Main\OceanStorPSModuleSys.ps1"}
    [pscustomobject]@{ModuleName="OceanStorPSModuleSAN";Location="$workDir\Main\OceanStorPSModuleSAN.ps1"}
    [pscustomobject]@{ModuleName="OceanStorPSModuleNAS";Location="$workDir\Main\OceanStorPSModuleNAS.ps1"}
    [pscustomobject]@{ModuleName="OceanStorPSModuleReport";Location="$workDir\Main\OceanStorPSModuleReport.ps1"}
)

foreach ($module in $ModulesToLoad){
    . $module.Location
}

export-DMStorage -Hostname "" -ReportFile ""

