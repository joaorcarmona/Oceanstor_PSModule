function Set-DMdnsServer {
    <#
    .SYNOPSIS
        Configures OceanStor DNS servers.

    .DESCRIPTION
        Configures OceanStor DNS servers. The submitted address list replaces the current DNS configuration.

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

    .PARAMETER DnsServer
        DNS server address list. Provide one or more IPv4 addresses separated by commas. The array order is preserved as DNS server priority.

    .INPUTS
        System.Management.Automation.PSCustomObject
        System.Array

        You can pipe an OceanStor session object to WebSession and provide DNS server addresses by property name.

    .OUTPUTS
		System.Collections.Hashtable
		System.String

		Returns the configured DNS server table on success. Returns an error string when the update fails.

    .EXAMPLE
        PS C:\> Set-DMdnsServer -webSession $session -DNSserver 8.8.8.8,1.1.1.1

    .NOTES
		Filename: Set-DMdnsServer.ps1

	.LINK
	#>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $false)]
        [array]$DNSserver
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $deviceManager
    }

    #Validate All IpAddresses in the Array
    foreach ($dns in $DNSserver) {
        $IPResult = Test-IPv4Address -IPv4 $dns
        if ($IPResult -eq $false) {
            # throw instead of exit to avoid terminating the caller's session
            throw "'$dns' is not a valid IPv4 address."
        }
    }

    $PostData = New-Object System.Collections.Hashtable

    $PostData.Add("ADDRESS", $DNSserver)
    $SetConfig = Invoke-DeviceManager -WebSession $session -Method "PUT" -Resource "dns_server" -BodyData $PostData

    if ($SetConfig.error.code -eq 0) {
        $result = Get-DMdnsServer -WebSession $session
    }
    else {
        $result = "error setting DNS Server"
    }

    return $result
}
