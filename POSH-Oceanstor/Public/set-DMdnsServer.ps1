function set-DMdnsServer
{
        <#
    .SYNOPSIS
        To Configure the Oceanstor DNS Server

    .DESCRIPTION
        To Cofnigure the Oceanstor DNS Server. It will overwrite the current config

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

    .PARAMETER DnsServer
        Mandatory paramater (array) to define the DNS Server configuration. Should be One or more IPv4 Address, coma separated.

    .OUTPUTS
		returns $true if sucess, returns error if fails

    .EXAMPLE
        PS C:\> set-DMdnsServer -webSession $session -DNSserver 8.8.8.8,1.1.1.1

    .NOTES
		Filename: set-DMdnsServer.ps1
		Author: Joao Carmona
		Modified date: 2022-06-5
		Version 0.1

	.LINK
	#>
    [Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [pscustomobject]$WebSession,
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [array]$DNSserver
	)

	if ($WebSession){
        $session = $WebSession
    } else {
        $session = $deviceManager
    }

    #Validate All IpAddresses in the Array
    foreach ($dns in $DNSserver)
    {
        $IPResult = test-IPv4Address -IPv4 $dns
        If ($IPResult -eq $false){
            write-Host $dns " isnt a valid IP Address"
            exit
        }
    }

    $PostData = New-Object System.Collections.Hashtable

    $PostData.Add("ADDRESS",$DNSserver)
    $SetConfig = invoke-DeviceManager -WebSession $session -Method "PUT" -Resource "dns_server" -BodyData $PostData

    if ($SetConfig.error.code -eq 0)
    {
        $result = get-DMdnsServer -WebSession $session
    } else {
        $result = "error setting DNS Server"
    }

    return $result
}