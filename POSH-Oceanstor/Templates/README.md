# Huawei Oceanstor_PSModule Templates

This XML files, are templates that represents all the properties that any object have, and that are going to be exported when any of these object types are used.

The XML schema explanation:

 + First field is the property name the properties/attribute (dont change this, because this maps the Object property)
 + Second is order that the property show up when the object is exported.
 + Third is the property description, describing the property values
 + Fourth is enable or disable tag (shown/exported or not shown/exported in the report). To disable one property you just need to change the <enabled> to 0 (ZERO).

```
Any change to templates included have impact on the default reports. If you want to make your own reports, is recommended to copy the existent template and modify the copy. That way you will have a fresh backup that can be called.
```

The default templates are loaded in the module variables, when the module is initialize by calling the file:
import-ReportTemplates.ps1 inside the private folder. This files have currently 6 global variables. It is expected that more could be added in the future.

```powershell
#Location for Lun Report Template
$global:Lunsv3ReportTemplate  = $workDir + "/Templates/Report-Lunsv3.xml"
$global:Lunsv6ReportTemplate  = $workDir + "/Templates/Report-Lunsv6.xml"
$global:HostsReportTemplate  = $workDir + "/Templates/Report-Hosts.xml"
$global:HostGroupsReportTemplate  = $workDir + "/Templates/Report-HostGroups.xml"
$global:LunGroupsReportTemplate  = $workDir + "/Templates/Report-LunGroups.xml"
$global:DisksReportTemplate  = $workDir + "/Templates/Report-Disks.xml"
```

## How to Use

### Disabling a property
**Before:**
```xml
    <property>
      <name>id</name>
      <order>1</order>
      <description></description>
      <enabled>1</enabled>
    </property>
```
**After**
```xml
    <property>
      <name>id</name>
      <order>1</order>
      <description></description>
      <enabled>0</enabled>
    </property>
```

### Changing the properties orders
**Before**
```xml
    <property>
      <name>Running Status</name>
      <order>6</order>
      <description></description>
      <enabled>1</enabled>
    </property>
    <property>
      <name>Enclosure ID</name>
      <order>7</order>
      <description></description>
      <enabled>1</enabled>
    </property>
```
**After**
**Before**
```xml
    <property>
      <name>Running Status</name>
      <order>8</order>
      <description></description>
      <enabled>1</enabled>
    </property>
    <property>
      <name>Enclosure ID</name>
      <order>7</order>
      <description></description>
      <enabled>1</enabled>
    </property>
```
```
If two properties have the same order value, both with show up, but based on the xml schema order. So if you have two properties with number 7, both will show up after the property 6.
```