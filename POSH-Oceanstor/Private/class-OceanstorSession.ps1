class OceanstorSession{
    #Define Hostname Property OceanstorDeviceManager
	[string]$Hostname

	#Define Host Credentials Property
	# dont need credential in the session, just use it to get the token and then discard it. Dont want to have the credentials in memory for long time
	#hidden [System.Management.Automation.PSCredential]$Credentials 

	#Define DeviceID Property
	[string]$DeviceId

	#Define WebSession Property (canonical)
	hidden [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession

	#Compatibility alias for legacy callers that still use Session
	hidden [Microsoft.PowerShell.Commands.WebRequestSession]$Session

	#Define Headers Array Property
	hidden [System.Collections.IDictionary]$Headers

	#Define TLS validation compatibility switch
	hidden [bool]$SkipCertificateCheck

	#Define Software Version
	[string]$Version

    # Constructor
    # Deliberately does not call Get-DMSystem here. On Linux/macOS, PowerShell
    # class constructors resolve function calls from the session scope rather
    # than the module scope, which bypasses Pester mocks set up inside the
    # module under test. Version is resolved by Connect-deviceManager after
    # construction instead, where normal function-scope mocking applies.
    OceanstorSession ([PSCustomObject] $logonSession, [System.Collections.IDictionary]$SessionHeader, [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession, [string] $hostname)
    {
        $this.DeviceId = $logonsession.data.deviceid
        $this.WebSession = $WebSession
        $this.Session = $WebSession
		$this.WebSession = $WebSession
        $this.Headers = $SessionHeader
        #$this.Credentials = $credentials
        $this.Hostname = $hostname
    }
}
