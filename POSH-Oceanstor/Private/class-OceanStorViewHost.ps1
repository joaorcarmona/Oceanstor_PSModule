class OceanStorViewHost
{
    #TODO
    hidden [pscustomobject]${Session}
	hidden [pscustomobject]${WebSession}
    [PSCustomObject]$Properties
    [PSCustomObject]$Paths
    [PSCustomObject]$Luns
    [PSCustomObject]$HostGroups
    [PSCustomObject]$vStores
    [PSCustomObject]${FC Initiators}
    [PSCustomObject]${ISCSI Initiators}

    OceanStorViewHost ([array]$thost,[psCustomObject]$WebSession)
    {
        $this.Session = $WebSession
		$this.WebSession = $WebSession
        $this.Properties = $thost
        $this.Paths = Get-DMHostLinks -WebSession $webSession

    }
}

