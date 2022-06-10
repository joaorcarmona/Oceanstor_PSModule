function new-DMLunReport{
    [Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$true)]
        [pscustomobject]$Object,
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=1,Mandatory=$false)]
        [xml]$ReportTemplate
    )

    # IF ReportTemplate not set, use the default one
    if ($ReportTemplate){
        $xmlTemplate = $ReportTemplate
    } else {
        $xmlTemplate = $LunsReportTemplate
    }

    [xml]$XMLFile = get-content -Path $xmlTemplate

    $lunsProperties = @()

    $propertiesCollected = $XMLFile.SelectNodes("/luns/properties/property[enabled=1]") | Sort-Object { [int] $_.order }

    $luns = @()

    foreach ($obj in $Object)
    {
        $lun = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        foreach ($property in $propertiesCollected.name)
        {
            $lun.Add($property,$obj.$property)
        }
        $luns += $lun
    }

    return $luns
}