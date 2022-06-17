function new-DMObjectReport{
    [Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$true)]
        [pscustomobject]$Object,
        [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=1,Mandatory=$false)]
    [ValidateSet("luns","hosts","hostgroups","lungroups")]
        [string]$ReportType,
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=2,Mandatory=$false)]
        [xml]$ReportTemplate
    )

    # IF ReportTemplate not set, use the default one
    if ($ReportTemplate){
        $xmlTemplate = $ReportTemplate
    } else {
        switch ($ReportType)
        {
            luns {$defaultTemplate = $LunsReportTemplate}
            hosts {$defaultTemplate = $HostsReportTemplate}
            hostgroups {$defaultTemplate = $HostGroupsReportTemplate}
            lungroups {$defaultTemplate = $LunGroupsReportTemplate}
        }
        $xmlTemplate = $defaultTemplate
    }

    [xml]$XMLFile = get-content -Path $xmlTemplate

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