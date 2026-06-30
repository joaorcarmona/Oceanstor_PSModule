[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '')]
class OceanStorMappingView {
    hidden [pscustomobject]${Session}
	hidden [pscustomobject]${WebSession}
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

    OceanStorMappingView([pscustomobject]$MappingViewReceived, [pscustomobject]$WebSession) {
        $this.Session = $WebSession
		$this.WebSession = $WebSession
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

    [psobject] Delete() {
        return Remove-DMMappingView -WebSession $this.Session -MappingViewName $this.Name -Confirm:$false
    }
}


