[array] $ModulesToLoad = @(
    [pscustomobject]@{ModuleName='OceanStorPSModuleClass';Location='C:\users\jcarmona\Documents\Scripts\Main\OceanStorPSModuleClass.ps1'}
    [pscustomobject]@{ModuleName='OceanStorPSModuleBase';Location='C:\users\jcarmona\Documents\Scripts\Main\OceanStorPSModuleBase.ps1'}
    [pscustomobject]@{ModuleName='OceanStorPSModuleSys';Location='C:\users\jcarmona\Documents\Scripts\Main\OceanStorPSModuleSys.ps1'}
    [pscustomobject]@{ModuleName='OceanStorPSModuleSAN';Location='C:\users\jcarmona\Documents\Scripts\Main\OceanStorPSModuleSAN.ps1'}
    [pscustomobject]@{ModuleName='OceanStorPSModuleNAS';Location='C:\users\jcarmona\Documents\Scripts\Main\OceanStorPSModuleNAS.ps1'}
    [pscustomobject]@{ModuleName='OceanStorPSModuleReport';Location='C:\users\jcarmona\Documents\Scripts\Main\OceanStorPSModuleReport.ps1'}
)

foreach ($module in $ModulesToLoad){
    . $module.Location
}
