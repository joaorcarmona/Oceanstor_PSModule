function Set-DMdnsServer {
    <#
    .SYNOPSIS
        Configures OceanStor DNS servers.

    .DESCRIPTION
        Configures OceanStor DNS servers. The submitted address list replaces the current DNS configuration.

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .PARAMETER DnsServer
        DNS server address list. Provide one or more IPv4 addresses separated by commas. The array order is preserved as DNS server priority.

    .INPUTS
        System.Management.Automation.PSCustomObject
        System.Array

        You can pipe an OceanStor session object to WebSession and provide DNS server addresses by property name.

    .OUTPUTS
		System.Management.Automation.PSCustomObject

		Returns the OceanStor API error object indicating success or failure of the modification.

    .EXAMPLE
        PS C:\> Set-DMdnsServer -webSession $session -DNSserver 8.8.8.8,1.1.1.1

    .NOTES
		Filename: Set-DMdnsServer.ps1

	.LINK
	#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [array]$DNSserver
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    #Validate All IpAddresses in the Array
    foreach ($dns in $DNSserver) {
        $IPResult = Test-IPv4Address -IPv4 $dns
        if ($IPResult -eq $false) {
            # throw instead of exit to avoid terminating the caller's session
            throw "'$dns' is not a valid IPv4 address."
        }
    }

    $PostData = @{ ADDRESS = $DNSserver }
    if ($PSCmdlet.ShouldProcess(($DNSserver -join ', '), 'Configure DNS servers')) {
        $response = Invoke-DeviceManager -WebSession $session -Method "PUT" -Resource "dns_server" -BodyData $PostData
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
