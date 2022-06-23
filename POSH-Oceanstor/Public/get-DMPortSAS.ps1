function get-DMPortSAS{
    <#
.SYNOPSIS
    To Get Huawei Oceanstor Storage configured SAS Ports

.DESCRIPTION
    Function to request Huawei Oceanstor Storage configured SAS Ports

.PARAMETER webSession
    Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

.INPUTS

.OUTPUTS
    returns the Huawei Oceanstor Storage configured SAS Ports in the system. Return an Array object.

.EXAMPLE

    PS C:\> get-DMPortSAS -webSession $session

    OR

    PS C:\> $sasPorts = get-DMPortSAS

.NOTES
    Filename: get-DMPortSAS.ps1
    Author: Joao Carmona
    Modified date: 2022-06-23
    Version 0.1

.LINK
#>
[Cmdletbinding()]
Param(
[Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
    [pscustomobject]$WebSession
)

if ($WebSession){
    $session = $WebSession
} else {
    $session = $deviceManager
}

$response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "sas_port" | Select-Object -ExpandProperty data
$sasPorts = New-Object System.Collections.ArrayList

foreach ($psas in $response)
{
    $saspObj = [OceanstorPortSAS]::new($psas)
    $sasPorts += $saspObj
}

$result = $sasPorts

return $result
}