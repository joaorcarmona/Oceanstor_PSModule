# Huawei Oceanstor_PSModule
Oceanstor PowerShell Module, is a module to operate with Huawei Oceanstor devices (v3) - v5 and v6 not tested but should work

Currently only get functions are developed, but in the future more operations could be added.

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

The Module is a powershell module to interact with Huawei Oceanstor Devices, via the REST API. All module was developed to allow a user to use all commands without having to pass arguments (unless for query filtering). The websession is optional parameters in all commands, if you are querying multiple storage at same time, if not, you just need to connect and start using the get commands.

To start, is necessary to connect to a Storage (single).
```powershell
#Connect to a storage (System will request to input your username and password)
$storage = connect-deviceManager -hostname "10.0.0.1" -Secure

#For unattended connection, pass the credentials in plain text (not recommended)
$storage = connect-deviceManager -hostname "10.0.0.1" -Unsecure -LoginUser "username" -LoginPwd "password"
```
Next the user can Query any command without requiring the input the username again.
```powershell
#Query all storage luns
$luns = get-DMLuns
```

For multiple storage is advised to work with the parameter websession:
```powershell
#Connect to 2 storages and save your session in different variables
$storage1 = connect-deviceManager -hostname "10.0.0.1" -Secure
$storage2 = connect-deviceManager -hostname "10.0.0.2" -Secure
```
Next the user can Query any command without requiring the input the username again, but you will need to input the webSession parameter
```powershell
#Query all storage luns
$storage1luns = get-DMLuns -webSession $storage1
$storage2luns = get-DMLuns -webSession $storage2
```

#### Export Storage Configuration to Excel
```powershell
#Connect to a storage (System will request to input your username and password)
$storage = connect-deviceManager -hostname "10.0.0.1" -Secure

#export all storage data to excel
export-DMStorageToExcel -OceanStor $storage -ReportFile "c:\temp\MyStorage.xlsx"
```

#### Search one lun by WWN
```powershell
#Connect to a storage (System will request to input your username and password)
$storage = connect-deviceManager -hostname "10.0.0.1" -Secure

#Search for a lun by Lun WWN
 $luns = get-DMlunsByWWN -webSession $storage -wwn "6a08cf810075766e1efc050700000005"
```

## Additional Resources

### Links

- [OceanStor V3 V300R006C50 REST Interface Reference] (https://support.huawei.com/enterprise/en/doc/EDOC1100136666)
