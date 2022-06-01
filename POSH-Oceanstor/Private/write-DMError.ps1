function write-DMError {
    [Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$true)]
        [PSCustomObject]$SessionError
    )

    $errorCode = $SessionError.code
    Write-Host -ForegroundColor Red -BackgroundColor Yellow "Error Code: "$errorCode
    $errorDescription = $SessionError.description
    Write-Host -ForegroundColor Red "Error Description: "$errorDescription
    $errorSuggestion = $SessionError.suggestion
    Write-Host -ForegroundColor Green "Suggestion: "$errorSuggestion

}