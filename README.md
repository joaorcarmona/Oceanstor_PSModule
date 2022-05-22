# Huawei Oceanstor_PSModule
Oceanstor PowerShell Module, is a module to operate with Huawei Oceanstor devices (v3) - v5 and v6 not tested but should work

Currently only get functions are developed, but in the future more operations could be added.

### How to Install

```powershell
# INstall
    # Download the POSH-Oceanstor from github
    # unzip the file
    # Extract the POSH-Oceanstor folder to your user Modules Location in $HOME\Documents\PowerShell\Modules
    # Or to System Wide Location C:\Program Files\WindowsPowerShell\Modules

# Import the POSH-Module
    Import-Module -name POSH-Module

# Get POSH-Oceanstor commands
    Get-Command -Module POSH-Module

# Get help
    Get-Help about_POSH-Oceanstor
```

### Examples

# Export Storage Configuration to Excel
```powershell
#Connect to a storage (System will request to input your username and password)
$storage = connect-deviceManager -hostname "10.10.10.10"

#export all storage data to excel
export-DMStorageToExcel -OceanStor $storage -ReportFile "c:\temp\MyStorage.xlsx"
```

# Search one lun by WWN
```powershell
#Connect to a storage (System will request to input your username and password)
$storage = connect-deviceManager -hostname "10.10.10.10"

#Search for a lun by Lun WWN
 $luns = get-DMlunsByWWN -webSession $storage -wwn "6a08cf810075766e1efc050700000005"
```

# Additional Resources

## Links

- [OceanStor V3 V300R006C50 REST Interface Reference] (https://support.huawei.com/enterprise/en/doc/EDOC1100136666)
