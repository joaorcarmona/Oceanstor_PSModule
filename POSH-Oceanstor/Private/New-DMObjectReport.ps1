function New-DMObjectReport{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,Position=0,Mandatory=$true)]
        [pscustomobject]$Object,
        [Parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,Position=1,Mandatory=$false)]
    [ValidateSet("lunsv3","lunsv6","hosts","hostgroups","lungroups","disks")]
        [string]$ReportType,
    [Parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,Position=2,Mandatory=$false)]
        [xml]$ReportTemplate
    )

    # IF ReportTemplate not set, use the default one
    if ($ReportTemplate){
        [xml]$XMLFile = $ReportTemplate
    } else {
        switch ($ReportType)
        {
            lunsv3 {$defaultTemplate = $Lunsv3ReportTemplate}
            lunsv6 {$defaultTemplate = $Lunsv6ReportTemplate}
            hosts {$defaultTemplate = $HostsReportTemplate}
            hostgroups {$defaultTemplate = $HostGroupsReportTemplate}
            lungroups {$defaultTemplate = $LunGroupsReportTemplate}
            disks {$defaultTemplate = $DisksReportTemplate}
        }
        [xml]$XMLFile = Get-content -Path $defaultTemplate
    }

    $propertiesCollected = $XMLFile.SelectNodes("/$ReportType/properties/property[enabled=1]") | Sort-Object { [int] $_.order }

    $returnObject = @()

    foreach ($obj in $Object)
    {
        $objectToAdd = New-Object -TypeName PsObject
        foreach ($property in $propertiesCollected.name)
        {
            $objectToAdd | Add-Member -MemberType NoteProperty -Name $property -Value $obj.$property
        }
        $returnObject += $objectToAdd
    }

    return $returnObject
}
