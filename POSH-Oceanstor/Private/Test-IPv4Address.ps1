function Test-IPv4Address {
    [Cmdletbinding()]
    [OutputType([bool])]
    Param(
    [Parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,Position=0,Mandatory=$true)]
        [string]$IPv4
    )

    $pattern = "^([1-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])(\.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])){3}$"

    $result = $false
    if ($IPv4 -match $pattern)
    {
        $result = $true
    }

    Return $result
}
