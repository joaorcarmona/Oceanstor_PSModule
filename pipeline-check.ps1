$ErrorActionPreference = 'Stop'
Import-Module .\POSH-Oceanstor\POSH-Oceanstor.psd1 -Force
$cmds = @(Get-Command -Module POSH-Oceanstor -CommandType Function | Where-Object {
  @($_.Parameters.Values | Where-Object { $_.ValueFromPipeline -eq $true -or $_.ValueFromPipelineByPropertyName -eq $true }).Count -gt 0
})
[pscustomobject]@{
  TotalPublicFunctions = @(Get-Command -Module POSH-Oceanstor -CommandType Function).Count
  FunctionsWithPipelineSupport = $cmds.Count
  Sample = @($cmds | Select-Object -First 15 -ExpandProperty Name)
} | ConvertTo-Json -Depth 5
