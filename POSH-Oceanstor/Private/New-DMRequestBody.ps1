function ConvertTo-DMRequestBody {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$BoundParameters,

        [Parameter(Mandatory)]
        [hashtable]$Map
    )

    $body = @{}
    foreach ($parameterName in $Map.Keys) {
        if ($BoundParameters.ContainsKey($parameterName)) {
            $body[$Map[$parameterName]] = $BoundParameters[$parameterName]
        }
    }

    return $body
}
