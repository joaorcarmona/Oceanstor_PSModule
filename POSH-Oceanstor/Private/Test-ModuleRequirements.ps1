if (!(Get-Module -ListAvailable -Name ImportExcel)) {
	Write-Warning "ImportExcel Module is not available or is not installed!"
	Write-Warning "To install it, run: Install-Module -Name ImportExcel"
	Write-Warning "For more information: https://github.com/dfinke/ImportExcel"
	throw "Required module 'ImportExcel' is not installed. Run: Install-Module -Name ImportExcel"
}