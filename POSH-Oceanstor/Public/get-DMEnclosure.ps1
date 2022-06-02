function get-DMEnclosure{
    <#
.SYNOPSIS
    To Get Huawei Oceanstor Storage Enclosures

.DESCRIPTION
    Function to request Huawei Oceanstor Enclosures in the system

.PARAMETER webSession
    Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

.INPUTS

.OUTPUTS
    returns the Huawei Oceanstor Storage Enclosures in the system. Return an Array object.

.EXAMPLE

    PS C:\> get-DMEnclosure -webSession $session

    OR

    PS C:\> $enclosures = get-DMEnclosure

.NOTES
    Filename: get-DMEnclosure.ps1
    Author: Joao Carmona
    Modified date: 2022-06-02
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

$response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "enclosure" | Select-Object -ExpandProperty data
$enclosures = New-Object System.Collections.ArrayList

foreach ($tenc in $response)
{
    $enc = [OceanStorEnclosure]::new($tenc)
    $enclosures += $enc
}

$result = $enclosures

return $result
}