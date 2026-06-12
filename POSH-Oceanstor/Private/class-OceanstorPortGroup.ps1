class OceanstorPortGroup {
    hidden [pscustomobject]${Session}
	hidden [pscustomobject]${WebSession}
    [string]${Id}
    [string]${Name}
    [string]${Description}
    [string]${Port Type}
    [string]${Port Count}
    [bool]${Is Mapped}
    [string]${vStore Id}
    [string]${vStore Name}

    OceanstorPortGroup([pscustomobject]$PortGroupReceived, [pscustomobject]$WebSession) {
        $this.Session = $WebSession
		$this.WebSession = $WebSession
        $this.Id = $PortGroupReceived.ID
        $this.Name = $PortGroupReceived.NAME
        $this.Description = $PortGroupReceived.DESCRIPTION
        $this.{Port Count} = $PortGroupReceived.portNum
        $this.{Is Mapped} = [System.Convert]::ToBoolean($PortGroupReceived.isAddToMappingView)
        $this.{vStore Id} = $PortGroupReceived.vstoreId
        $this.{vStore Name} = $PortGroupReceived.vstoreName

        switch ([string]$PortGroupReceived.portType) {
            '0' { $this.{Port Type} = 'Physical Port' }
            '1' { $this.{Port Type} = 'Logical Port' }
            '16' { $this.{Port Type} = 'Unassigned' }
            default { $this.{Port Type} = $PortGroupReceived.portType }
        }
    }
}


