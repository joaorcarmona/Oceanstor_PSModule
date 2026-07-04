function Get-DMLocalUser {
    <#
    .SYNOPSIS
        Gets OceanStor local user information.
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
        $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "user/$encodedId" |
            Select-DMResponseData
        return [OceanStorLocalUser]::new($response, $session)
    }

    $response = Invoke-DMPagedRequest -WebSession $session -Resource 'user'
    return @($response | ForEach-Object { [OceanStorLocalUser]::new($_, $session) })
}
