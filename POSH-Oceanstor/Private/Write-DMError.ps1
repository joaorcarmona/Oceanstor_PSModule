function Write-DMError {
    [Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,Position=0,Mandatory=$true)]
        [PSCustomObject]$SessionError
    )

    $errorCode = $SessionError.code
    $errorDescription = $SessionError.description
    $errorSuggestion = $SessionError.suggestion
    Write-Warning "Error Code: $errorCode"
    Write-Warning "Error Description: $errorDescription"
    Write-Warning "Suggestion: $errorSuggestion"

}