function Get-DMPortSAS {
    <#
.SYNOPSIS
    To Get Huawei Oceanstor Storage configured SAS Ports

.DESCRIPTION
    Function to request Huawei Oceanstor Storage configured SAS Ports

.PARAMETER webSession
    Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

.INPUTS
    System.Management.Automation.PSCustomObject

    You can pipe an OceanStor session object to WebSession.

.OUTPUTS
    OceanstorPortSAS

    Returns SAS port objects.

.EXAMPLE

    PS C:\> Get-DMPortSAS -webSession $session

    OR

    PS C:\> $sasPorts = Get-DMPortSAS

.NOTES
    Filename: Get-DMPortSAS.ps1

.LINK
#>
    [Cmdletbinding()]
    [OutputType([System.Collections.ArrayList])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $defaultDisplaySet = "Id", "Name", "Health Status", "Running Status", "Port Location"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "sas_port" | Select-DMResponseData
    $sasPorts = New-Object System.Collections.ArrayList

    foreach ($psas in $response) {
        $saspObj = [OceanstorPortSAS]::new($psas, $session)
        [void]$sasPorts.Add($saspObj)
    }

    $sasPorts | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $sasPorts

    return $result
}
