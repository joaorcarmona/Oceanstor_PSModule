#Get Script RootPath
$workDir = $(get-item $PSScriptRoot).Parent.FullName

#Get public and private function definition files.
$Public  = @( Get-ChildItem -Path $workDir\POSH-Oceanstor\Public\*.ps1 -ErrorAction SilentlyContinue )
$Private  = @( Get-ChildItem -Path $workDir\POSH-Oceanstor\Private\*.ps1 -ErrorAction SilentlyContinue )


#Dot source the files
Foreach($import in @($Public + $Private))
{
    Try
    {
        . $import.fullname
    }
    Catch
    {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}

