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
RootModule = "POSH-Oceanstor.psm1"

# Version number of this module.
ModuleVersion = "1.1.0"

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
    "Format/OceanstorLunSnapshot.format.ps1xml"
    "Format/OceanstorFileSystemSnapshot.format.ps1xml"
    "Format/OceanstorProtectionGroup.format.ps1xml"
    "Format/OceanstorSnapshotConsistencyGroup.format.ps1xml"
    "Format/OceanstorReplicationPair.format.ps1xml"
    "Format/OceanstorReplicationConsistencyGroup.format.ps1xml"
    "Format/OceanstorHyperMetroDomain.format.ps1xml"
    "Format/OceanstorHyperMetroPair.format.ps1xml"
    "Format/OceanstorHyperMetroConsistencyGroup.format.ps1xml"
    "Format/OceanstorLun.format.ps1xml"
    "Format/OceanstorHost.format.ps1xml"
    "Format/OceanstorHostGroup.format.ps1xml"
    "Format/OceanstorLunGroup.format.ps1xml"
    "Format/OceanstorFileSystem.format.ps1xml"
    "Format/OceanstorDtree.format.ps1xml"
    "Format/OceanstorNFSShare.format.ps1xml"
    "Format/OceanstorNFSclient.format.ps1xml"
    "Format/OceanstorQuota.format.ps1xml"
)

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module
FunctionsToExport = @(
    'Add-DMLunToHyperCDPSchedule'
    'Add-DMHostGroupToMappingView'
    'Add-DMHostToHostGroup'
    'Add-DMLunGroupToMappingView'
    'Add-DMLunToLunGroup'
    'Add-DMLunToProtectionGroup'
    'Add-DMFailoverGroupMember'
    'Add-DMHyperMetroPairToConsistencyGroup'
    'Add-DMmapLunGroupToHost'
    'Add-DMmapLunGroupToHostGroup'
    'Add-DMmapLunToHost'
    'Add-DMPortGroupToMappingView'
    'Add-DMPortToPortGroup'
    'Add-DMQosAssociation'
    'Add-DMQuorumServerToHyperMetroDomain'
    'Add-DMReplicationPairToConsistencyGroup'
    'Add-DMSyslogServer'
    'Clear-DMAlarm'
    'Clear-DMRequestTrace'
    'Connect-deviceManager'
    'Disconnect-deviceManager'
    'Get-DMAccessMode'
    'Set-DMAccessMode'
    'Disable-DMFeature'
    'Disable-DMRequestTrace'
    'Disable-DMHyperCDPSchedule'
    'Disable-DMFileSystemReplicationPairSecondaryProtection'
    'Disable-DMLocalUserSession'
    'Disable-DMPerformanceMonitoring'
    'Disable-DMReplicationPairSecondaryProtection'
    'Enable-DMFeature'
    'Enable-DMRequestTrace'
    'Enable-DMHyperCDPSchedule'
    'Enable-DMFileSystemReplicationPairSecondaryProtection'
    'Enable-DMLunSnapshot'
    'Enable-DMPerformanceMonitoring'
    'Enable-DMReplicationPairSecondaryProtection'
    'Enable-DMSnapshotConsistencyGroup'
    'Export-DeviceManager'
    'Export-DMInventory'
    'Export-DMStorageToExcel'
    'Get-DMAlarm'
    'Get-DMAlarmHistory'
    'Get-DMAlarmMasking'
    'Get-DMAlarmType'
    'Get-DMbbu'
    'Get-DMCapacityHistory'
    'Get-DMCertificate'
    'Get-DMcofferDisk'
    'Get-DMController'
    'Get-DMControllerPerformance'
    'Get-DMDiskbyLocation'
    'Get-DMDiskByStoragePool'
    'Get-DMdisk'
    'Get-DMDiskPerformance'
    'Get-DMdnsServer'
    'Get-DMEnclosure'
    'Get-DMEquipmentStatus'
    'Get-DMFeature'
    'Get-DMFailoverGroup'
    'Get-DMFailoverGroupMember'
    'Get-DMFiberChannelInitiator'
    'Get-DMFileHyperMetroDomain'
    'Get-DMFileSystem'
    'Get-DMFileSystemPerformance'
    'Get-DMFileSystemReplicationPair'
    'Get-DMFileSystemSnapshot'
    'Get-DMfreeDisk'
    'Get-DMhostGroup'
    'Get-DMHostInitiator'
    'Get-DMHostLink'
    'Get-DMhost'
    'Get-DMHostPerformance'
    'Get-DMhostbyFilter'
    'Get-DMhostbyHostGroup'
    'Get-DMhostbyId'
    'Get-DMhostbyName'
    'Get-DMHyperCDPSchedule'
    'Get-DMHyperMetroConsistencyGroup'
    'Get-DMHyperMetroDomain'
    'Get-DMHyperMetroPair'
    'Get-DMInterfaceModule'
    'Get-DMIscsiInitiator'
    'Get-DMLif'
    'Get-DMLLDPWorkingMode'
    'Get-DMlunGroup'
    'Get-DMlun'
    'Get-DMLunbyFilter'
    'Get-DMLunPerformance'
    'Get-DMlunbyLunGroup'
    'Get-DMlunByName'
    'Get-DMlunByWWN'
    'Get-DMLunSnapshot'
    'Get-DMLocalUser'
    'Get-DMMappingView'
    'Get-DMnfsFileClient'
    'Get-DMNtpServer'
    'Get-DMNtpStatus'
    'Get-DMNvmeInitiator'
    'Get-DMPerformance'
    'Get-DMPerformanceHistory'
    'Get-DMPerformanceMonitoring'
    'Get-DMPerformanceReportTask'
    'Get-DMPortBond'
    'Get-DMPortETH'
    'Get-DMPortFc'
    'Get-DMPortGroup'
    'Get-DMPortPerformance'
    'Get-DMPortSAS'
    'Get-DMProtectionGroup'
    'Get-DMQosPolicy'
    'Get-DMQuorumServer'
    'Get-DMQuota'
    'Get-DMRemoteDevice'
    'Get-DMRemoteLun'
    'Get-DMReplicationConsistencyGroup'
    'Get-DMReplicationPair'
    'Get-DMRequestTrace'
    'Get-DMRole'
    'Get-DMRolePermission'
    'Get-DMShare'
    'Get-DMSnmpConfig'
    'Get-DMSnmpSecurityPolicy'
    'Get-DMSnmpTrapServer'
    'Get-DMSnmpUsmUser'
    'Get-DMSnapshotConsistencyGroup'
    'Get-DMstoragePool'
    'Get-DMStoragePoolPerformance'
    'Get-DMSystem'
    'Get-DMSystemPerformance'
    'Get-DMSyslogNotification'
    'Get-DMTimeZone'
    'Get-DMutcTime'
    'Get-DMvLan'
    'Get-DMvStore'
    'Get-DMVStorePair'
    'Get-DMWorkLoadType'
    'Invoke-DMPerformanceReportTask'
    'Join-DMFileHyperMetroDomain'
    'Lock-DMLocalUser'
    'New-DMCifsShare'
    'New-DMdTree'
    'New-DMFailoverGroup'
    'New-DMFiberChannelInitiator'
    'New-DMFileHyperMetroDomain'
    'New-DMFileSystem'
    'New-DMFileSystemReplicationPair'
    'New-DMFileSystemSnapshot'
    'New-DMHost'
    'New-DMHostGroup'
    'New-DMHyperCDPSchedule'
    'New-DMHyperMetroConsistencyGroup'
    'New-DMHyperMetroDomain'
    'New-DMHyperMetroPair'
    'New-DMIscsiInitiator'
    'New-DMLocalUser'
    'New-DMLun'
    'New-DMLunGroup'
    'New-DMLunSnapshot'
    'New-DMLunSnapshotCopy'
    'New-DMMappingView'
    'New-DMnfsClient'
    'New-DMnfsShare'
    'New-DMNvmeInitiator'
    'New-DMLif'
    'New-DMPerformanceReportTask'
    'New-DMPortBond'
    'New-DMPortGroup'
    'New-DMvLan'
    'New-DMProtectionGroup'
    'New-DMQosPolicy'
    'New-DMQuota'
    'New-DMReplicationConsistencyGroup'
    'New-DMReplicationPair'
    'New-DMRole'
    'New-DMSnmpTrapServer'
    'New-DMSnmpUsmUser'
    'New-DMSnapshotConsistencyGroup'
    'New-DMSnapshotConsistencyGroupCopy'
    'New-DMVStorePair'
    'Remove-DMCifsShare'
    'Remove-DMDTree'
    'Remove-DMFailoverGroup'
    'Remove-DMFailoverGroupMember'
    'Remove-DMFiberChannelInitiator'
    'Remove-DMFiberChannelInitiatorFromHost'
    'Remove-DMFileHyperMetroDomain'
    'Remove-DMFileSystem'
    'Remove-DMFileSystemSnapshot'
    'Remove-DMHost'
    'Remove-DMHostFromHostGroup'
    'Remove-DMHostGroup'
    'Remove-DMHyperMetroConsistencyGroup'
    'Remove-DMHyperMetroPair'
    'Remove-DMHyperMetroPairFromConsistencyGroup'
    'Remove-DMLunFromHyperCDPSchedule'
    'Remove-DMHostGroupFromMappingView'
    'Remove-DMIscsiInitiator'
    'Remove-DMIscsiInitiatorFromHost'
    'Remove-DMLun'
    'Remove-DMHyperCDPSchedule'
    'Remove-DMHyperMetroDomain'
    'Remove-DMLocalUser'
    'Remove-DMLunFromLunGroup'
    'Remove-DMLunFromProtectionGroup'
    'Remove-DMLunGroup'
    'Remove-DMLunGroupFromMappingView'
    'Remove-DMLunSnapShot'
    'Remove-DMmapLunFromHost'
    'Remove-DMMappingView'
    'Remove-DMNfsClient'
    'Remove-DMNfsShare'
    'Remove-DMNvmeInitiator'
    'Remove-DMNvmeInitiatorFromHost'
    'Remove-DMLif'
    'Remove-DMPerformanceReportTask'
    'Remove-DMPortBond'
    'Remove-DMPortFromPortGroup'
    'Remove-DMPortGroup'
    'Remove-DMPortGroupFromMappingView'
    'Remove-DMProtectionGroup'
    'Remove-DMQosAssociation'
    'Remove-DMQosPolicy'
    'Remove-DMQuorumServerFromHyperMetroDomain'
    'Remove-DMQuota'
    'Remove-DMReplicationConsistencyGroup'
    'Remove-DMReplicationPair'
    'Remove-DMReplicationPairFromConsistencyGroup'
    'Remove-DMRole'
    'Remove-DMSnmpTrapServer'
    'Remove-DMSnmpUsmUser'
    'Remove-DMSnapshotConsistencyGroup'
    'Remove-DMSyslogServer'
    'Remove-DMvLan'
    'Remove-DMVStorePair'
    'Remove-DMunmapLunGroupFromHost'
    'Remove-DMunmapLunGroupFromHostGroup'
    'Rename-DMFileSystem'
    'Rename-DMHost'
    'Rename-DMHostGroup'
    'Rename-DMLun'
    'Rename-DMLunGroup'
    'Rename-DMMappingView'
    'Rename-DMPortGroup'
    'Rename-DMProtectionGroup'
    'Rename-DMstoragePool'
    'Resize-DMLunSnapshot'
    'Reset-DMLocalUserPassword'
    'Restart-DMLunSnapshot'
    'Restart-DMSnapshotConsistencyGroup'
    'Restore-DMFileSystemSnapshot'
    'Restore-DMLunSnapshot'
    'Restore-DMSnapshotConsistencyGroup'
    'Save-DMPerformanceReportFile'
    'Set-DMAlarmMasking'
    'Set-DMCifsShare'
    'Set-DMdnsServer'
    'Set-DMdTree'
    'Set-DMFailoverGroup'
    'Set-DMFileSystem'
    'Set-DMHost'
    'Set-DMHostGroup'
    'Set-DMHyperCDPSchedule'
    'Set-DMHyperMetroConsistencyGroup'
    'Set-DMHyperMetroDomain'
    'Set-DMHyperMetroPair'
    'Set-DMHyperMetroPairPreferredPolicy'
    'Set-DMLocalUser'
    'Set-DMLun'
    'Set-DMLunGroup'
    'Set-DMMappingView'
    'Set-DMLif'
    'Set-DMLLDPWorkingMode'
    'Set-DMnfsClient'
    'Set-DMnfsShare'
    'Set-DMPerformanceMonitoring'
    'Set-DMPortBond'
    'Set-DMPortGroup'
    'Set-DMProtectionGroup'
    'Set-DMQosPolicy'
    'Set-DMQuota'
    'Set-DMReplicationConsistencyGroup'
    'Set-DMReplicationPair'
    'Set-DMReplicationPairMode'
    'Set-DMVStorePair'
    'Set-DMRole'
    'Set-DMvLan'
    'Set-DMNtpServer'
    'Set-DMSnmpCommunity'
    'Set-DMSnmpConfig'
    'Set-DMSnmpSecurityPolicy'
    'Set-DMSnmpTrapServer'
    'Set-DMSnmpUsmUser'
    'Set-DMFileSystemReplicationPairSecondaryReadOnly'
    'Set-DMSyslogNotification'
    'Set-DMTimeZone'
    'Set-DMutcTime'
    'Split-DMFileHyperMetroDomain'
    'Split-DMVStorePair'
    'Split-DMReplicationConsistencyGroup'
    'Split-DMReplicationPair'
    'Start-DMFileHyperMetroDomain'
    'Start-DMHyperMetroConsistencyGroup'
    'Start-DMHyperMetroPair'
    'Start-DMQosPolicy'
    'Stop-DMQosPolicy'
    'Suspend-DMHyperMetroConsistencyGroup'
    'Suspend-DMHyperMetroPair'
    'Switch-DMFileHyperMetroDomain'
    'Switch-DMHyperMetroConsistencyGroup'
    'Switch-DMHyperMetroPairPriority'
    'Switch-DMReplicationConsistencyGroup'
    'Switch-DMReplicationPair'
    'Switch-DMVStorePair'
    'Sync-DMHyperMetroConsistencyGroup'
    'Sync-DMHyperMetroPair'
    'Sync-DMReplicationConsistencyGroup'
    'Sync-DMReplicationPair'
    'Sync-DMVStorePair'
    'Test-DMNtpServer'
    'Test-DMSnmpTrapServer'
    'Unlock-DMLocalUser'
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
    'Delete-DMFailoverGroup'
    'Delete-DMFailoverGroupMember'
    'Get-DMFailoverGroups'
    'Get-DMFailoverGroupMembers'
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
    'Get-DMHyperCDPSchedules'
    'Get-DMInterfaceModules'
    'Delete-DMLif'
    'Delete-DMPortBond'
    'Delete-DMvLan'
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
    'Enable-DMQosPolicy'
    'Disable-DMQosPolicy'
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

        # Prerelease string of this module (leave commented for a STABLE release;
        # set to "alpha1"/"beta"/etc. to publish a prerelease to the Gallery)
        # Prerelease = "beta"

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
