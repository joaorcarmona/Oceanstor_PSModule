# Huawei Oceanstor_PSModule Templates

This XML files, are templates that represents all the properties that any object have, and that are going to be exported when any of this object types are used.

The XMl schema start by reference the properties/atribute name, following the order that the property show up, the property description and if is enable or disable (shown/exported or not shown/exported in the report). To disable one property you just need to change the <enabled> to 0 (ZERO).


### How to Use

## Disabling a property
Before:
```xml
    <property>
      <name>id</name>
      <order>1</order>
      <description></description>
      <enabled>1</enabled>
    </property>
```
After
```xml
    <property>
      <name>id</name>
      <order>1</order>
      <description></description>
      <enabled>0</enabled>
    </property>
```
