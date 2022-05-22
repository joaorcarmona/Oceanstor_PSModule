#Check depencies
if (!(Get-Module -ListAvailable -Name ImportExcel )) {
	Write-Host "ImportExcel Module is not available or is not installed!`r`n"
	Write-Host "`r`n"
	Write-Host "`r`n"
	Write-Host "To install the ImportExcel Module, run the following command from the powershell command line (Powershell v5, is required):`r`n"
	Write-Host "`r`n"
	Write-Host "Install-Module -Name ImportExcel"
	Write-Host "`r`n"
	Write-Host "`r`n"
	write-Host "For more information, consult the ImportExcel page: https://github.com/dfinke/ImportExcel"
	exit
}