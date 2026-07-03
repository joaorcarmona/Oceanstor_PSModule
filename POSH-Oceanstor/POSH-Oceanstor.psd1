#
# Module manifest for module "POSH-Oceanstor"
#
# developed originally by Warren Frame "RamblingCookieMonster" (https://github.com/RamblingCookieMonster)
#
# modified by: Joao Carmona
# Generated 22/05/2022
#

@{

# Script module or binary module file associated with this manifest.
RootModule = "posh-oceanstor.psm1"

# Version number of this module.
ModuleVersion = "0.9.5"

# ID used to uniquely identify this module
GUID = "67f4a145-d50d-4c26-bd26-b1303fd48aa1"

# Author of this module
Author = "Joao Carmona"

# Company or vendor of this module
#CompanyName = "Unknown"

# Copyright statement for this module
Copyright = "(c) 2026 Joao Carmona All rights reserved."

# Description of the functionality provided by this module
Description = "PowerShell module to interact with Huawei Oceanstor Devices"

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = "6.0"

# Name of the Windows PowerShell host required by this module
# PowerShellHostName = ""

# Minimum version of the Windows PowerShell host required by this module
# PowerShellHostVersion = ""

# Minimum version of Microsoft .NET Framework required by this module
# DotNetFrameworkVersion = ""

# Minimum version of the common language runtime (CLR) required by this module
# CLRVersion = ""

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ""

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @("ImportExcel")

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller"s environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
FormatsToProcess = @(
    "Format\OceanstorLunSnapshot.format.ps1xml"
    "Format\OceanstorFileSystemSnapshot.format.ps1xml"
    "Format\OceanstorProtectionGroup.format.ps1xml"
    "Format\OceanstorSnapshotConsistencyGroup.format.ps1xml"
    "Format\OceanstorLun.format.ps1xml"
    "Format\OceanstorHost.format.ps1xml"
    "Format\OceanstorHostGroup.format.ps1xml"
    "Format\OceanstorLunGroup.format.ps1xml"
    "Format\OceanstorFileSystem.format.ps1xml"
    "Format\OceanstorDtree.format.ps1xml"
    "Format\OceanstorNFSShare.format.ps1xml"
    "Format\OceanstorNFSclient.format.ps1xml"
)

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module
FunctionsToExport = @(
    'Add-DMHostGroupToMappingView'
    'Add-DMHostToHostGroup'
    'Add-DMHostToMappingView'
    'Add-DMLunGroupToMappingView'
    'Add-DMLunToLunGroup'
    'Add-DMLunToMappingView'
    'Add-DMPortGroupToMappingView'
    'Add-DMPortToPortGroup'
    'Connect-deviceManager'
    'Disconnect-deviceManager'
    'Enable-DMLunSnapshot'
    'Enable-DMSnapshotConsistencyGroup'
    'Export-DeviceManager'
    'Export-DMInventory'
    'Export-DMStorageToExcel'
    'Get-DMAlarm'
    'Get-DMbbu'
    'Get-DMcofferDisk'
    'Get-DMController'
    'Get-DMDiskbyLocation'
    'Get-DMDiskByStoragePool'
    'Get-DMdisk'
    'Get-DMdnsServer'
    'Get-DMEnclosure'
    'Get-DMFiberChannelInitiator'
    'Get-DMFileSystem'
    'Get-DMFileSystemSnapshot'
    'Get-DMfreeDisk'
    'Get-DMhostGroup'
    'Get-DMHostInitiator'
    'Get-DMHostLink'
    'Get-DMhost'
    'Get-DMhostbyFilter'
    'Get-DMhostbyHostGroup'
    'Get-DMhostbyId'
    'Get-DMhostbyName'
    'Get-DMInterfaceModule'
    'Get-DMIscsiInitiator'
    'Get-DMLif'
    'Get-DMlunGroup'
    'Get-DMlun'
    'Get-DMLunbyFilter'
    'Get-DMlunbyLunGroup'
    'Get-DMlunByName'
    'Get-DMlunByWWN'
    'Get-DMLunSnapshot'
    'Get-DMMappingView'
    'Get-DMnfsFileClient'
    'Get-DMNvmeInitiator'
    'Get-DMPortBond'
    'Get-DMPortETH'
    'Get-DMPortFc'
    'Get-DMPortGroup'
    'Get-DMPortSAS'
    'Get-DMProtectionGroup'
    'Get-DMShare'
    'Get-DMSnapshotConsistencyGroup'
    'Get-DMstoragePool'
    'Get-DMSystem'
    'Get-DMvLan'
    'Get-DMvStore'
    'Get-DMWorkLoadType'
    'Get-DMWorkLoadTypebyFilter'
    'New-DMCifsShare'
    'New-DMdTree'
    'New-DMFiberChannelInitiator'
    'New-DMFileSystem'
    'New-DMFileSystemSnapshot'
    'New-DMHost'
    'New-DMHostGroup'
    'New-DMIscsiInitiator'
    'New-DMLun'
    'New-DMLunGroup'
    'New-DMLunSnapshot'
    'New-DMLunSnapshotCopy'
    'New-DMMappingView'
    'New-DMnfsClient'
    'New-DMnfsShare'
    'New-DMNvmeInitiator'
    'New-DMPortGroup'
    'New-DMProtectionGroup'
    'New-DMSnapshotConsistencyGroup'
    'New-DMSnapshotConsistencyGroupCopy'
    'Remove-DMCifsShare'
    'Remove-DMDTree'
    'Remove-DMFiberChannelInitiator'
    'Remove-DMFiberChannelInitiatorFromHost'
    'Remove-DMFileSystem'
    'Remove-DMFileSystemSnapshot'
    'Remove-DMHost'
    'Remove-DMHostFromHostGroup'
    'Remove-DMHostFromMappingView'
    'Remove-DMHostGroup'
    'Remove-DMHostGroupFromMappingView'
    'Remove-DMIscsiInitiator'
    'Remove-DMIscsiInitiatorFromHost'
    'Remove-DMLun'
    'Remove-DMLunFromLunGroup'
    'Remove-DMLunFromMappingView'
    'Remove-DMLunGroup'
    'Remove-DMLunGroupFromMappingView'
    'Remove-DMLunSnapShot'
    'Remove-DMMappingView'
    'Remove-DMNfsClient'
    'Remove-DMNfsShare'
    'Remove-DMNvmeInitiator'
    'Remove-DMNvmeInitiatorFromHost'
    'Remove-DMPortFromPortGroup'
    'Remove-DMPortGroup'
    'Remove-DMPortGroupFromMappingView'
    'Remove-DMProtectionGroup'
    'Remove-DMSnapshotConsistencyGroup'
    'Rename-DMFileSystem'
    'Rename-DMHost'
    'Rename-DMHostGroup'
    'Rename-DMLun'
    'Rename-DMLunGroup'
    'Rename-DMPortGroup'
    'Resize-DMLunSnapshot'
    'Restart-DMLunSnapshot'
    'Restart-DMSnapshotConsistencyGroup'
    'Restore-DMFileSystemSnapshot'
    'Restore-DMLunSnapshot'
    'Restore-DMSnapshotConsistencyGroup'
    'Set-DMdnsServer'
    'Set-DMFileSystem'
    'Set-DMHost'
    'Set-DMHostGroup'
    'Set-DMLun'
    'Set-DMLunGroup'
    'Set-DMPortGroup'
)

# Cmdlets to export from this module
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = @()

# Aliases to export from this module (backward-compatibility names for renamed commands)
AliasesToExport = @(
    'Get-DMAlarms'
    'Get-DMbbus'
    'Get-DMcofferDisks'
    'Get-DMControllers'
    'Get-DMdisks'
    'Get-DMDisksByStoragePool'
    'Get-DMEnclosures'
    'Get-DMFileSystemSnapshots'
    'Get-DMfreeDisks'
    'Get-DMhostGroups'
    'Get-DMHostInitiators'
    'Get-DMHostLinks'
    'Get-DMhosts'
    'Get-DMhostsbyFilter'
    'Get-DMhostsbyHostGroup'
    'Get-DMhostsbyId'
    'Get-DMhostsbyName'
    'Get-DMInterfaceModules'
    'Get-DMLifs'
    'Get-DMlunGroups'
    'Get-DMluns'
    'Get-DMLunsbyFilter'
    'Get-DMlunsbyLunGroup'
    'Get-DMlunsByName'
    'Get-DMlunsByWWN'
    'Get-DMLunSnapshots'
    'Get-DMShares'
    'Get-DMstoragePools'
    'Get-DMvLans'
    'Get-DMWorkLoadTypes'
    'Get-DMWorkLoadTypesbyFilter'
)

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
         Tags = @("Huawei", "Oceanstor", "DeviceManager", "Dorado")

        # A URL to the license for this module.
         LicenseUri = "https://github.com/joaorcarmona/Oceanstor_PSModule/blob/master/LICENSE"

        # A URL to the main website for this project.
         ProjectUri = "https://github.com/joaorcarmona/Oceanstor_PSModule/"

        # A URL to an icon representing this module.
        # IconUri = ""

        # ReleaseNotes of this module
         ReleaseNotes = "https://github.com/joaorcarmona/Oceanstor_PSModule/blob/master/RELEASE_NOTES.md"

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ""

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ""

}
