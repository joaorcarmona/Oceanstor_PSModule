class OceanStorViewHost
{
    #TODO
    hidden [pscustomobject]${Session}
    [PSCustomObject]$Properties
    [PSCustomObject]$Paths
    [PSCustomObject]$Luns
    [PSCustomObject]$HostGroups
    [PSCustomObject]$vStores
    [PSCustomObject]${FC Initiators}
    [PSCustomObject]${ISCSI Initiators}

    OceanStorViewHost ([array]$thost,[psCustomObject]$webSession)
    {
        $this.Session = $webSession
        $this.Properties = $thost
        $this.Paths = get-DMHostLinks -WebSession $webSession

    }
}
