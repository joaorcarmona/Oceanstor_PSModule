function Get-DMEnclosure {
    <#
.SYNOPSIS
    To Get Huawei Oceanstor Storage Enclosures

.DESCRIPTION
    Function to request Huawei Oceanstor Enclosures in the system

.PARAMETER webSession
    Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

.INPUTS
    System.Management.Automation.PSCustomObject

    You can pipe an OceanStor session object to WebSession.

.OUTPUTS
    OceanStorEnclosure

    Returns enclosure objects.

.EXAMPLE

    PS C:\> Get-DMEnclosure -webSession $session

    OR

    PS C:\> $enclosures = Get-DMEnclosure

.NOTES
    Filename: Get-DMEnclosure.ps1

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

    $defaultDisplaySet = "Id", "Name", "Health Status", "Running Status", "Model"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "enclosure" | Select-DMResponseData
    $enclosures = New-Object System.Collections.ArrayList

    foreach ($tenc in $response) {
        $enc = [OceanStorEnclosure]::new($tenc, $session)
        [void]$enclosures.Add($enc)
    }

    $enclosures | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $enclosures

    return $result
}

Set-Alias -Name Get-DMEnclosures -Value Get-DMEnclosure
