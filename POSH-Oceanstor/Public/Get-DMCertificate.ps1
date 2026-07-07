function Get-DMCertificate {
    <#
    .SYNOPSIS
        Gets the Huawei OceanStor certificate inventory (read-only).

    .DESCRIPTION
        Queries the array certificate inventory via the documented read-only
        endpoint (GET certificate, OceanStor Dorado 6.1.6 REST Interface
        Reference section 4.3.5.3.1). Returns one OceanStorCertificate object
        per certificate-type slot (HTTPS, DeviceManager, Syslog, NTP, ...),
        including slots where no certificate is installed (Status 'Absent').

        This cmdlet never mutates certificates and never returns private-key
        material — the endpoint only exposes subjects, issuers, fingerprints,
        serial numbers, algorithms, and validity dates.

    .PARAMETER WebSession
        Optional session to use on the REST call. If not defined, the module's
        cached $script:CurrentOceanstorSession session is used.

    .PARAMETER VstoreId
        Optional vStore ID. Only required in the vStore scenario, per the REST
        reference. When omitted, the array-level inventory is returned.

    .INPUTS
        System.Management.Automation.PSCustomObject

        You can pipe an OceanStor session object WebSession.

    .OUTPUTS
        OceanStorCertificate

        One object per certificate-type slot reported by the array. Slots with
        no installed certificate have Status 'Absent' and empty
        Subject/Fingerprint/ValidTo values.

    .EXAMPLE
        PS C:\> Get-DMCertificate -WebSession $session

        Lists every certificate slot on the array.

    .EXAMPLE
        PS C:\> Get-DMCertificate -WebSession $session | Where-Object Status -eq 'Valid'

        Lists only slots with an installed, valid certificate.

    .EXAMPLE
        PS C:\> Get-DMCertificate | Where-Object { $_.ValidTo -and $_.ValidTo -lt (Get-Date).AddDays(90) }

        Finds certificates expiring within 90 days.

    .NOTES
        Filename: Get-DMCertificate.ps1
        Read-only. Certificate mutation is intentionally not implemented; see
        docs/system-management/certificates.md.

    .LINK
    #>
    [CmdletBinding()]
    [OutputType('OceanStorCertificate')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$VstoreId
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $defaultDisplaySet = 'CertificateType', 'Status', 'Subject', 'Issuer', 'ValidTo'
    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )
    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $resource = 'certificate'
    if ($VstoreId) {
        $resource += "?vstoreId=$([uri]::EscapeDataString($VstoreId))"
    }

    $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource $resource | Select-DMResponseData

    $certificates = New-Object System.Collections.ArrayList
    foreach ($entry in @($response)) {
        if ($null -eq $entry) { continue }
        $certificateObject = [OceanStorCertificate]::new($entry)
        $certificateObject | Add-Member MemberSet PSStandardMembers $standardMembers -Force
        [void]$certificates.Add($certificateObject)
    }

    return $certificates
}
