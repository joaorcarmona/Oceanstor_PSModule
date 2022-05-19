function new-OceanstorStorage{
	[Cmdletbinding()]
	Param(
		[Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$true)]
			[String]$Hostname
	)

	$result = [OceanstorStorage]::new($Hostname)

	return $result
}

function export-DMStorage{
	[Cmdletbinding()]
	Param(
		[Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$true,ParameterSetName="NewConnection")]
			[String]$Hostname,
		[Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$true,ParameterSetName="CurrentConnection")]
			[PSCustomObject]$OceanStor,
		[Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$true)]
			[string]$ReportFile
	)

	if ($hostname -ne $null)
	{
		$storage = new-OceanstorStorage -Hostname $Hostname
	} else {
		$storage = $OceanStor
	}

	#TODO Use SaveFileDialog Form to select file

	Export-Excel $ReportFile -AutoSize -TableName System -InputObject $storage.system -WorksheetName "Basic System"
	Export-Excel $ReportFile -AutoSize -TableName Disks -InputObject $storage.disks -WorksheetName "System Disks"
	Export-Excel $ReportFile -AutoSize -TableName StoragePools -InputObject $storage.StoragePools -WorksheetName "Storage Pools"
	Export-Excel $ReportFile -AutoSize -TableName Luns -InputObject $storage.Luns -WorksheetName "Luns"
	Export-Excel $ReportFile -AutoSize -TableName LunGroups -InputObject $storage.LunGroups -WorksheetName "Lun Groups"
	Export-Excel $ReportFile -AutoSize -TableName Hosts -InputObject $storage.hosts -WorksheetName "Hosts"
	Export-Excel $ReportFile -AutoSize -TableName HostGroups -InputObject $storage.HostGroups -WorksheetName "Hosts Groups"
	Export-Excel $ReportFile -AutoSize -TableName vStores -InputObject $storage.vStores -WorksheetName "System vStores"

}