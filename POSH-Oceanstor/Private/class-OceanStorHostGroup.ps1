[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '')]
class OceanStorHostGroup{
	#Define Properties
	hidden [pscustomobject]${Session}
	hidden [pscustomobject]${WebSession}
	[int]${Id}
	[string]${Name}
	[string]$Description
	[string]${HostGroup Type}
	[int]${vStore ID}
	[string]${vStore Name}
	[boolean]${Is Mapped}
	[string]${Host Member Number} # for v6
	[string]${Mapped Luns Number} # for v6
	[string]${Total Capacity} # for v6
	[string]${Allocated Capacity} # For v6
	[string]${Protection Capacity} # For V6

	OceanStorHostGroup ([array]$HostGroupReceived, [pscustomobject]$WebSession)
	{
		$this.Session = $WebSession
		$this.WebSession = $WebSession
		$this.{Id} = $HostGroupReceived.ID
		$this.{Name} = $HostGroupReceived.NAME
		$this.Description = $HostGroupReceived.DESCRIPTION
		$this.{HostGroup Type} = $HostGroupReceived.TYPE

		switch($HostGroupReceived.TYPE)
		{
			14 {$this.{HostGroup Type} = "Host Group"}
		}

		$this.{vStore ID} = $HostGroupReceived.vstoreid
		$this.{vStore Name} = $HostGroupReceived.vstoreName

		if ($HostGroupReceived.ISADD2MAPPINGVIEW -eq "false")
		{
			$this.{Is Mapped} = $false
		} elseif ($HostGroupReceived.ISADD2MAPPINGVIEW -eq "true") {
			$this.{Is Mapped} = $true
		}

		# Dorado 6.1.6 returns hostNumber; the legacy misspelled hostNumbe is kept
		# as a fallback for older/V3 arrays that only return the old field name.
		$this.{Host Member Number} = if ($null -ne $HostGroupReceived.hostNumber) { $HostGroupReceived.hostNumber } else { $HostGroupReceived.hostNumbe }
		$this.{Mapped Luns Number} = $HostGroupReceived.mappingLunNumber #for v6
		$this.{Total Capacity} = $HostGroupReceived.capacity / 1GB #for v6
		$this.{Allocated Capacity} = $HostGroupReceived.allocatedCapacity / 1GB #for v6
		$this.{Protection Capacity} = $HostGroupReceived.protectionCapacity / 1GB #for v6

	}

	[psobject] Rename([string]$NewName)
	{
		$result = Rename-DMHostGroup -WebSession $this.Session -HostGroupName $this.Name -NewName $NewName -Confirm:$false
		if ($result.Code -eq 0) {
			$this.Name = $NewName
		}
		return $result
	}

	[psobject] Delete()
	{
		return Remove-DMHostGroup -WebSession $this.Session -HostGroupName $this.Name -Confirm:$false
	}
}


