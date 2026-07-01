function Get-DMShare {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage Shares

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage Shares

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.PARAMETER shareType
		Mamdatory paramter to define the Share Type to Query ("NFS","CIFS")

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession and provide shareType by property name.

	.OUTPUTS
		OceanStorCIFSShare
		OceanStorNFSShare

		Returns CIFS or NFS share objects, depending on shareType.

	.EXAMPLE

		PS C:\> Get-DMShare -webSession $session -shareType CIFS

		OR

		PS C:\> $shares = Get-DMShare -shareType NFS

	.NOTES
		Filename: Get-DMShare.ps1

	.LINK
	#>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(Position = 1, Mandatory = $true)]
        [ValidateSet("CIFS", "NFS")]
        [string]$shareType
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $deviceManager
    }

    $defaultDisplaySet = "Id", "Name", "Share Path", "FileSystem ID", "vStore Name"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    switch ($shareType) {
        CIFS {
            $resourceQuery = "CIFSHARE"
        }
        NFS {
            $resourceQuery = "NFSHARE"
        }
    }

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource $resourceQuery | Select-DMResponseData
    $shares = New-Object System.Collections.ArrayList

    foreach ($tshare in $response) {
        switch ($shareType) {
            CIFS {
                $share = [OceanStorCIFSShare]::new($tshare, $session)
            }
            NFS {
                $share = [OceanStorNFSShare]::new($tshare, $session)
            }
        }

        [void]$shares.Add($share)
    }

    $shares | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $shares
    return $result
}

Set-Alias -Name Get-DMShares -Value Get-DMShare
