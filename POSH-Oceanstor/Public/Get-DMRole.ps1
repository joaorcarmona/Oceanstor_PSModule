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

    # The live 'role' endpoint pads range-paged responses to the requested page size
    # with copies of the first role instead of honoring the offset (role?range=[0-100]
    # returns 100 copies of role ID 1), so Invoke-DMPagedRequest never sees a short
    # page and loops forever. The role collection is small and the unpaged response
    # is correct, so query it unpaged.
    $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource 'role' |
        Select-DMResponseData
    return @($response | ForEach-Object { [OceanStorRole]::new($_, $session) })
}
