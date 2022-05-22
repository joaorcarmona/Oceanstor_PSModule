function get-DMdnsServer{
    <#
    .SYNOPSIS
        To Get Huawei Oceanstor Storage configured DNS Servers

    .DESCRIPTION
        Returns Huawei Oceanstor Storage Configured DNS Servers

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

    .EXAMPLE
        PS C:\> get-DMdnsServer -webSession $session

	.EXAMPLE

		PS C:\> $dnsServers = get-DMdnsServer

    .NOTES
		Filename: get-DMdnsServer.ps1
		Author: Joao Carmona
		Modified date: 2022-05-22
		Version 0.2

	.LINK
	#>
    [Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [pscustomobject]$WebSession
	)

	if ($WebSession){
        $session = $WebSession
    } else {
        $session = $deviceManager
    }

    $response = $(invoke-DeviceManager -WebSession $session -Method "GET" -Resource "dns_server" | Select-Object -ExpandProperty data | Select-Object -ExpandProperty ADDRESS).ToString()

    $DnsServers = @{}

    $splitResponse = $($response.Substring(0, $response.Length -1)).substring(1).Split(",")

    $i = 1

	foreach ($dnsS in $splitResponse)
	{
        $dnstoAdd = $($dnsS.Substring(0, $dnsS.Length -1)).substring(1).Split(",")
        if ($dnstoAdd -ne "")
        {
            $DnsServers.add("DNS Server $i",$dnstoAdd)
            $i = $i + 1
        }
	}

    return $DnsServers
}