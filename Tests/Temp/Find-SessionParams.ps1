$base = 'POSH-Oceanstor'
$output = Get-ChildItem -Path $base -Recurse -Filter '*.ps1' | Where-Object { $_.FullName -match '\\(Public|Private)\\' } | ForEach-Object {
  $text = Get-Content -LiteralPath $_.FullName -Raw
  $hasSessionParam = [regex]::Match($text, '(?m)^\s*param\([\s\S]{0,200}?\[.*?\]\$Session\b').Success
  $hasWebSessionParam = [regex]::Match($text, '(?m)^\s*param\([\s\S]{0,200}?\[.*?\]\$WebSession\b').Success
  if ($hasSessionParam -or $hasWebSessionParam) {
    [pscustomobject]@{
      File = $_.FullName
      HasSessionParam = $hasSessionParam
      HasWebSessionParam = $hasWebSessionParam
    }
  }
}
$output | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath '.\Tests\Temp\Find-SessionParams.json' -Encoding utf8
$output | Format-Table -AutoSize
