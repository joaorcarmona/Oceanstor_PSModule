function Get-DMHyperMetroPair {
    <#
    .SYNOPSIS
        Gets OceanStor HyperMetro pairs.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    [OutputType([OceanstorHyperMetroPair])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(ParameterSetName = 'ByName', Position = 0)]
        [string]$Name,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

    if ($PSCmdlet.ParameterSetName -eq 'ById') {
        $encodedId = [uri]::EscapeDataString($Id)
        $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "HyperMetroPair/$encodedId" |
            Select-DMResponseData
        return [OceanstorHyperMetroPair]::new($response, $session)
    }

    $response = Invoke-DMPagedRequest -WebSession $session -Resource 'HyperMetroPair'
    $pairs = foreach ($pairData in @($response)) {
        $pair = [OceanstorHyperMetroPair]::new($pairData, $session)
        if ($Name -and $pair.{Local Object Name} -notlike $Name -and $pair.{Remote Object Name} -notlike $Name -and $pair.Id -notlike $Name) {
            continue
        }
        $pair
    }

    return @($pairs)
}
