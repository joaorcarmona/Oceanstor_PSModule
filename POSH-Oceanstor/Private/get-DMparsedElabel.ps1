function get-DMparsedElabel
{
    [Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$true)]
        [string]$eLabelString
    )

    $eLabels = New-Object System.Collections.ArrayList
    $eLabels = $eLabelString.split("`r`n")

    $labels = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"

    foreach ($label in $eLabels)
    {
        if ($label -match "\a|BoardType|BarCode|Item|Description|Manufactured|VendorName|IssueNumber|CLEICode|BOM")
        {
            $t = $label.Split("=")
            $labels.add($t[0],$t[1])
        }
    }

    $response = $labels
    return $response
}