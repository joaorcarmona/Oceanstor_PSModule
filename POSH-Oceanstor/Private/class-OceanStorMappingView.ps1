class OceanStorMappingView {
    hidden [pscustomobject]${Session}
    [string]${Id}
    [string]${Name}
    [string]${Description}
    [string]${Health Status}
    [string]${Running Status}
    [string]${Host Group Id}
    [string]${LUN Group Id}
    [string]${Port Group Id}
    [string]${vStore Id}
    [string]${vStore Name}

    OceanStorMappingView([pscustomobject]$MappingViewReceived, [pscustomobject]$Session) {
        $this.Session = $Session
        $this.Id = $MappingViewReceived.ID
        $this.Name = $MappingViewReceived.NAME
        $this.Description = $MappingViewReceived.DESCRIPTION
        $this.{Health Status} = $MappingViewReceived.HEALTHSTATUS
        $this.{Running Status} = $MappingViewReceived.RUNNINGSTATUS
        $this.{Host Group Id} = $MappingViewReceived.HOSTGROUPID
        $this.{LUN Group Id} = $MappingViewReceived.LUNGROUPID
        $this.{Port Group Id} = $MappingViewReceived.PORTGROUPID
        $this.{vStore Id} = $MappingViewReceived.vstoreId
        $this.{vStore Name} = $MappingViewReceived.vstoreName
    }
}
