function Get-DMRole {
    <#
    .SYNOPSIS
        Gets OceanStor role information.
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    [OutputType([pscustomobject[]])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [string]$Id
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    if ($PSCmdlet.ParameterSetName -eq 'ById') {
        $encodedId = [uri]::EscapeDataString($Id)
        $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "role/$encodedId" |
            Select-DMResponseData
        return [OceanStorRole]::new($response, $session)
    }

    $response = Invoke-DMPagedRequest -WebSession $session -Resource 'role'
    return @($response | ForEach-Object { [OceanStorRole]::new($_, $session) })
}
