# Huawei Oceanstor_PSModule
Oceanstor PowerShell Module, is a module to operate with Huawei Oceanstor devices (v6) - Previous versions should work in limited way. Please report any bugs.

Current module version: 0.9.3

The module includes commands for inventory, reporting, host and initiator
management, storage-resource creation, mapping-view operations, and snapshot
management.

## How to Install

```powershell
# Install
    # Download the POSH-Oceanstor from github
    # unzip the file
    # Extract the POSH-Oceanstor folder to your user Modules Location in $HOME\Documents\PowerShell\Modules
    # Or to System Wide Location C:\Program Files\WindowsPowerShell\Modules

# Import the POSH-Module
    Import-Module -name posh-oceanstor

# Get POSH-Oceanstor commands
    Get-Command -Module posh-oceanstor

# Get help
    Get-Help about_POSH-Oceanstor
```

### Examples

The module is a PowerShell module to interact with Huawei OceanStor devices through the REST API. All commands are designed to work without extra arguments unless you are filtering results. The WebSession parameter is optional on all commands. If you are querying multiple storage systems at the same time, pass the WebSession object returned by Connect-deviceManager.

To start, it is necessary to connect to a storage system.
```powershell
# Connect to a storage. By default, PowerShell securely prompts for your credentials.
$storage = Connect-deviceManager -Hostname "10.0.0.1" -PassThru

# The -Secure switch remains available for the interactive prompt form.
$storage = Connect-deviceManager -Hostname "10.0.0.1" -PassThru -Secure

# For unattended operation, provide a PSCredential obtained from a secure source.
# For example, import an encrypted credential exported for the same user and machine.
$credential = Import-Clixml -Path "$HOME\.oceanstor\device-manager.credential.xml"
$storage = Connect-deviceManager -Hostname "10.0.0.1" -PassThru -Credential $credential

# A SecureString password may also be paired with a user name.
$storage = Connect-deviceManager -Hostname "10.0.0.1" -PassThru -LoginUser "username" -LoginPwd $securePassword
```
Next the user can Query any command without requiring the input the username again.
```powershell
#Query all storage luns
$luns = Get-DMlun
```

For multiple storage systems, use the WebSession parameter:
```powershell
# Connect to two storages and save each WebSession in a different variable.
$storage1 = Connect-deviceManager -Hostname "10.0.0.1" -PassThru
$storage2 = Connect-deviceManager -Hostname "10.0.0.2" -PassThru
```
Next, query any command without re-entering credentials, but pass the WebSession parameter explicitly:
```powershell
# Query all storage LUNs
$storage1luns = Get-DMlun -WebSession $storage1
$storage2luns = Get-DMlun -WebSession $storage2
```

#### Export Storage Configuration to Excel
```powershell
# Connect to a storage (PowerShell securely prompts for credentials).
$storage = Connect-deviceManager -Hostname "10.0.0.1" -PassThru

#export all storage data to excel
Export-DMStorageToExcel -OceanStor $storage -ReportFile "c:\temp\MyStorage.xlsx" -IncludeObject full

#export some properties to excel (can me choosen multiple from: "luns","system","hostgroups","lungroups","disks","hosts","vstores","storagepools",)
Export-DMStorageToExcel -OceanStor $storage -ReportFile "c:\temp\MyStorage.xlsx" -IncludeObject luns, lungroups
```

#### Search one lun by WWN
```powershell
# Connect to a storage (PowerShell securely prompts for credentials).
$storage = Connect-deviceManager -Hostname "10.0.0.1" -PassThru

#Search for a lun by Lun WWN
 $luns = Get-DMlunByWWN -WebSession $storage -wwn "6a08cf810075766e1efc050700000005"
```

## Additional Resources

NOTE: This Module have been modfied to support Powershell version 6 and 7. Previous version will not work.

### Links

- [OceanStor V3 V300R006C50 REST Interface Reference] (https://support.huawei.com/enterprise/en/doc/EDOC1100136666)
- [OceanStor Dorado 6.1.6 REST Interface Reference] (https://support.huawei.com/enterprise/en/doc/EDOC1100324309)
