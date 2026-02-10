class OceanstorSession{
    #Define Hostname Property OceanstorDeviceManager
	[string]$Hostname

	#Define Host Credentials Property
	# dont need credential in the session, just use it to get the token and then discard it. Dont want to have the credentials in memory for long time
	#hidden [System.Management.Automation.PSCredential]$Credentials 

	#Define DeviceID Property
	[string]$DeviceId

	#Define WebSession Property
	hidden [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession

	#Define Headers Array Property
	hidden [System.Collections.IDictionary]$Headers

	#Define iBaseToken Property
	hidden [string]$iBaseToken

	#Define Software Version
	[string]$Version

    # Constructor
    OceanstorSession ([PSCustomObject] $logonSession, [System.Collections.IDictionary]$SessionHeader, [Microsoft.PowerShell.Commands.WebRequestSession]$webSession, [string] $hostname)
    {
        $this.DeviceId = $logonsession.data.deviceid
        $this.WebSession = $WebSession
        $this.Headers = $SessionHeader
        $this.iBaseToken = $logonsession.data.iBaseToken
        #$this.Credentials = $credentials
        $this.Hostname = $hostname

		$getDeviceManager = get-DMSystem -WebSession $this

		$this.Version = $getDeviceManager.version
    }
}