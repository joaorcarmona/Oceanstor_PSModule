function Invoke-DMPagedRequest {
    <#
    .SYNOPSIS
        Retrieves all pages of a collection resource from the OceanStor REST API.

    .DESCRIPTION
        Calls Invoke-DeviceManager in a loop, appending range=[start-end] query parameters
        until the API returns fewer results than the requested page size, indicating the last
        page has been reached. Returns the combined raw data array from all pages.

        The end boundary is exclusive (confirmed against a live array: range=[0-99] with
        PageSize 100 returned exactly 99 records, not 100), so each page requests
        [start, start+PageSize) rather than a closed [start, start+PageSize-1] interval.

        The OceanStor API returns at most PageSize objects per request when no range is
        specified, silently truncating larger collections. This helper ensures every object
        in a collection is retrieved regardless of size.

        If the array rejects the range parameter outright (error code 50331651, "The entered
        parameter is incorrect") on the first page, this falls back to a single unpaged request
        and warns, since an unpaged response on some firmware silently truncates to PageSize
        instead of erroring -- there is no way to distinguish "returned everything" from
        "silently truncated" from the response alone.

    .PARAMETER WebSession
        Optional session returned by Connect-deviceManager. The module's cached $script:CurrentOceanstorSession
        session is used when omitted.

    .PARAMETER Resource
        REST resource path to page through. If the path already contains query parameters
        (i.e. contains '?'), range parameters are appended with '&'; otherwise '?' is used.

    .PARAMETER PageSize
        Number of results to request per page. Defaults to 100, the OceanStor maximum per
        single request.
    #>
    param(
        [pscustomobject]$WebSession,

        [Parameter(Mandatory)]
        [string]$Resource,

        [ValidateRange(1, 100)]
        [int]$PageSize = 100
    )

    $allData = [System.Collections.Generic.List[object]]::new()
    $start = 0
    $separator = if ($Resource -match '\?') { '&' } else { '?' }

    do {
        $end = $start + $PageSize
        $pagedResource = "${Resource}${separator}range=[$start-$end]"

        $response = Invoke-DeviceManager -WebSession $WebSession -Method 'GET' -Resource $pagedResource
        $errorProperty = if ($null -ne $response) { $response.PSObject.Properties['error'] } else { $null }
        if ($null -ne $errorProperty -and $errorProperty.Value.Code -ne 0) {
            if ($start -eq 0 -and $errorProperty.Value.Code -eq 50331651) {
                Write-Warning "Resource '$Resource' rejected the range parameter (code 50331651); falling back to a single unpaged request. If the collection exceeds $PageSize items and the array's unpaged endpoint truncates rather than erroring, this may silently return an incomplete result."
                $response = Invoke-DeviceManager -WebSession $WebSession -Method 'GET' -Resource $Resource
                $errorProperty = if ($null -ne $response) { $response.PSObject.Properties['error'] } else { $null }
                if ($null -eq $errorProperty -or $errorProperty.Value.Code -eq 0) {
                    $dataProperty = if ($null -ne $response) { $response.PSObject.Properties['data'] } else { $null }
                    $fallbackPage = if ($null -ne $dataProperty) { @($dataProperty.Value) } else { @() }
                    return $fallbackPage
                }
            }
            throw (Get-DMApiErrorMessage -Code $errorProperty.Value.Code -Description $errorProperty.Value.description -ResourceContext $pagedResource)
        }
        $dataProperty = if ($null -ne $response) { $response.PSObject.Properties['data'] } else { $null }
        $page = if ($null -ne $dataProperty) { @($dataProperty.Value) } else { @() }

        foreach ($item in $page) {
            $allData.Add($item)
        }

        $start += $PageSize
    } while ($page.Count -eq $PageSize)

    return $allData.ToArray()
}
