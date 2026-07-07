# Shared -WhatIf regression helper for mutator test suites (network, DR, ...).
# Dot-source this file into the suite's test module (next to the cmdlets under
# test) and drive it from a -ForEach case table where each case supplies the
# mutating command name and a parameter splat satisfying its mandatory
# parameters. The suite's Invoke-DeviceManager stub or mock is responsible for
# capturing requests; this helper only asserts that nothing was captured.
function Assert-DMWhatIfMakesNoApiCall {
    param(
        [Parameter(Mandatory)]
        [string]$Command,

        [hashtable]$Parameters = @{},

        # Scriptblock returning the request(s) captured since the case reset its
        # capture state; $null or empty means no API call was made under -WhatIf.
        [Parameter(Mandatory)]
        [scriptblock]$GetCapturedRequest
    )

    (Get-Command -Name $Command).Parameters.ContainsKey('WhatIf') |
        Should -BeTrue -Because "$Command must declare SupportsShouldProcess so -WhatIf is honored"

    $null = & $Command @Parameters -WhatIf

    & $GetCapturedRequest | Should -BeNullOrEmpty -Because "$Command -WhatIf must not call Invoke-DeviceManager or send a request body"
}
