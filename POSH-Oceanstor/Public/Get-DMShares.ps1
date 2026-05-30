function Get-DMShares {
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

	.OUTPUTS
		returns the Huawei Oceanstor Storage Shares

	.EXAMPLE

		PS C:\> Get-DMShares -webSession $session -shareType CIFS

		OR

		PS C:\> $shares = Get-DMShares -shareType NFS

	.NOTES
		Filename: Get-DMShares.ps1
		Author: Joao Carmona
		Modified date: 2022-05-28
		Version 0.2

	.LINK
	#>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $false)]
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

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource $resourceQuery | Select-Object -ExpandProperty data
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
