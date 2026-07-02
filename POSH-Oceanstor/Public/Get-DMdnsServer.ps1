function Get-DMdnsServer {
    <#
    .SYNOPSIS
        To Get Huawei Oceanstor Storage configured DNS Servers

    .DESCRIPTION
        Returns Huawei Oceanstor Storage Configured DNS Servers

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .INPUTS
        System.Management.Automation.PSCustomObject

        You can pipe an OceanStor session object to WebSession.

    .OUTPUTS
		System.Collections.Hashtable

        Returns the configured DNS server addresses keyed by DNS server position.

    .EXAMPLE
        PS C:\> Get-DMdnsServer -webSession $session

	.EXAMPLE

		PS C:\> $dnsServers = Get-DMdnsServer

    .NOTES
		Filename: Get-DMdnsServer.ps1

	.LINK
	#>
    [Cmdletbinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $addressData = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "dns_server" |
        Select-DMResponseData |
        Select-Object -ExpandProperty ADDRESS

    # OceanStor returns ADDRESS as a JSON-encoded array string, e.g. '["10.0.0.1","10.0.0.2"]'.
    $addresses = if ($addressData -is [string]) {
        @(ConvertFrom-Json -InputObject $addressData -ErrorAction Stop)
    }
    else {
        @($addressData)
    }

    $DnsServers = @{}
    $i = 1
    foreach ($address in $addresses) {
        if ($address) {
            $DnsServers.add("DNS Server $i", $address)
            $i = $i + 1
        }
    }

    return $DnsServers
}
