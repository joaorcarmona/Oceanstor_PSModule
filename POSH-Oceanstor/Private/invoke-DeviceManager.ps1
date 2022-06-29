function invoke-DeviceManager{
	<#
	.SYNOPSIS
		Invokes a the Huawei Oceanstor Rest API

	.DESCRIPTION
		Function to to invoke the Huawei Oceanstor REST API, by method "GET","PUT","POST","DELETE" for any of the resources.

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used
	.PARAMETER method
		Mandatory parameter to define the REST call method to be used. Acceptable Values "GET","PUT","POST","DELETE"
	.PARAMETER resource
		Mandatory parameter to define the resource to be invoke. Any resource defines by Huawei Oceanstor REST API is acceptable

	.INPUTS

	.OUTPUTS
		returns the results of Huawei Oceanstor REST API call

	.EXAMPLE

		PS C:\> invoke-DeviceManager -webSession $session -method "GET" -resource "lun"

		OR

		PS C:\> $hosts = invoke-DeviceManager -method "GET" -resource "host"

	.NOTES
		Filename: invoke-DeviceManager.ps1
		Author: Joao Carmona
		Modified date: 2022-05-22
		Version 0.2

	.LINK
	#>
    [Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [pscustomobject]$WebSession,
    [Parameter(Position=1,Mandatory=$true)]
        [ValidateSet("GET","POST","PUT","DELETE")]
        [string]$Method,
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=2,Mandatory=$true)]
        [String]$Resource,
	[Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Mandatory=$false)]
		[System.Collections.Hashtable]$BodyData
	)

    if ($WebSession){
        $session = $WebSession
    } else {
        $session = $deviceManager
    }

	$RestURI = "https://$($session.hostname):8088/deviceManager/rest/$($session.DeviceId)/$resource"

	if ($BodyData)
	{
		$JsonBody = ConvertTo-Json $BodyData
		$result = Invoke-RestMethod -Method $Method -uri $RestURI -Headers $session.Headers -WebSession $session.WebSession -ContentType "application/json" -Credential $session.Credentials -Body $JsonBody
	} else {
		$result = Invoke-RestMethod -Method $Method -uri $RestURI -Headers $session.Headers -WebSession $session.WebSession -ContentType "application/json" -Credential $session.Credentials
	}

    if ($result.error.code -ne 0)
    {
        Write-Host $result.error
        exit
    }

	return $result
}