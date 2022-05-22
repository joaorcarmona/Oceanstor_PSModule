class OceanstorSession{
    #Define Hostname Property OceanstorDeviceManager
	hidden [string]$Hostname

	#Define Host Credentials Property
	hidden [System.Management.Automation.PSCredential]$Credentials

	#Define DeviceID Property
	hidden [string]$DeviceId

	#Define WebSession Property
	hidden [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession

	#Define Headers Array Property
	hidden [System.Collections.IDictionary]$Headers

	#Define iBaseToken Property
	hidden [string]$iBaseToken

	#Define Software Version
	hidden [string]$Version

    # Constructor
    OceanstorSession ([PSCustomObject] $logonSession, [System.Collections.IDictionary]$SessionHeader, [Microsoft.PowerShell.Commands.WebRequestSession]$webSession, [string] $hostname, [System.Management.Automation.PSCredential]$credentials)
    {
        $this.DeviceId = $logonsession.data.deviceid
        $this.WebSession = $WebSession
        $this.Headers = $SessionHeader
        $this.iBaseToken = $logonsession.data.iBaseToken
        $this.Credentials = $credentials
        $this.Hostname = $hostname

		$getDeviceManager = get-DMSystem -WebSession $this

		$this.Version = $getDeviceManager.version
    }
}