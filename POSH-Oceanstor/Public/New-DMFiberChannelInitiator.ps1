function New-DMFiberChannelInitiator {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({
            if (validate-WWNAddress -WWN $_) { return $true }
            throw 'WWN must contain 16 hexadecimal characters and cannot be all zeros or all Fs.'
        })]
        [string]$WWN,

        [ValidatePattern('^[A-Za-z0-9_.-]{1,31}$')]
        [string]$Name,

        [ValidateScript({
            $candidate = $_
            $session = if ($WebSession) { $WebSession } else { $deviceManager }
            $hosts = @(get-DMhosts -WebSession $session)
            $matches = @($hosts | Where-Object Name -EQ $candidate)
            if ($matches.Count -eq 1) { return $true }
            if ($matches.Count -gt 1) { throw "HostName is ambiguous because more than one host is named '$candidate'." }
            throw "Invalid HostName. Valid values are: $($hosts.Name -join ', ')"
        })]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $session = if ($fakeBoundParameters.ContainsKey('WebSession')) { $fakeBoundParameters.WebSession } else { $deviceManager }
            (get-DMhosts -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
        })]
        [string]$HostName,

        [ValidateSet('Default', 'ThirdParty')]
        [string]$Multipath = 'Default',

        [ValidateSet('Preferred', 'NonPreferred')]
        [string]$PathType = 'Preferred',

        [ValidateSet('EarlyALUA', 'CommonALUA', 'NoALUA', 'SpecialALUA')]
        [string]$FailoverMode = 'CommonALUA',

        [ValidateRange(0, 3)]
        [int]$SpecialModeType,

        [string]$VstoreId
    )

    $session = if ($WebSession) { $WebSession } else { $deviceManager }
    $body = @{
        ID            = $WWN
        MULTIPATHTYPE = @{ Default = 0; ThirdParty = 1 }[$Multipath]
    }
    if ($Name) { $body.NAME = $Name }
    if ($HostName) {
        $hostObject = @(get-DMhosts -WebSession $session | Where-Object Name -EQ $HostName)[0]
        $body.PARENTTYPE = 21
        $body.PARENTID = $hostObject.Id
    }
    if ($Multipath -eq 'ThirdParty') {
        $body.PATHTYPE = @{ Preferred = 0; NonPreferred = 1 }[$PathType]
        $body.FAILOVERMODE = @{ EarlyALUA = 0; CommonALUA = 1; NoALUA = 2; SpecialALUA = 3 }[$FailoverMode]
        if ($FailoverMode -eq 'SpecialALUA') { $body.SPECIALMODETYPE = $SpecialModeType }
    }
    if ($VstoreId) { $body.vstoreId = $VstoreId }

    $response = invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'fc_initiator' -BodyData $body
    if ($response.error.Code -eq 0) {
        return [OceanstorHostinitiatorFC]::new($response.data, $session)
    }
    return $response.error
}
