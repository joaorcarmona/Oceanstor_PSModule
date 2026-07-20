# developed originally by Warren Frame "RamblingCookieMonster" (https://github.com/RamblingCookieMonster)

#Load the session class first so other classes can reference [OceanstorSession] in their constructors.
    . $PSScriptRoot/Private/class-OceanstorSession.ps1

#Get public and private function definition files.
    $Public  = @( Get-ChildItem -Path $PSScriptRoot/Public/*.ps1 -ErrorAction SilentlyContinue )
    $Private = @( Get-ChildItem -Path $PSScriptRoot/Private/*.ps1 -ErrorAction SilentlyContinue |
        Where-Object Name -ne 'class-OceanstorSession.ps1' )

#Dot source the files
    foreach($import in @($Public + $Private))
    {
        try
        {
            . $import.fullname
        }
        catch
        {
            Write-Error -Message "Failed to import function $($import.fullname): $_"
        }
    }

# Here I might...
    # Read in or create an initial config file and variable
    # Export Public functions ($Public.BaseName) for WIP modules
    # Set variables visible to the module and its functions only

#Module-scoped cache of the active OceanStor session, set by Connect-deviceManager and
#used as the fallback for every command's -WebSession parameter when it is omitted.
    $script:CurrentOceanstorSession = $null

#Module-scoped REST debug-trace state, managed by Enable/Disable/Get/Clear-DMRequestTrace.
#Initialized here so reads are safe even under Set-StrictMode before tracing is enabled.
    $script:DeviceManagerTraceAction  = $null
    $script:DeviceManagerTraceEntries = [System.Collections.Generic.List[object]]::new()
    $script:DeviceManagerTraceDepth   = 1
    $script:DeviceManagerTraceConsole = $false
    $script:DeviceManagerTraceLogPath = $null

#Resolve the feature state for this import and cache it so Get-DMFeature can report what
#is active in the current session without re-reading disk. Get-DMFeatureState never throws
#on a missing/broken config, so a bad config can never stop the module from importing.
    $script:DMFeatureState = Get-DMFeatureState

#Filter exports by enabled features. A file whose BaseName is not mapped to any feature
#fails open (stays exported); the FeatureMap Pester suite catches map gaps at CI time.
    $enabledFeatures = $script:DMFeatureState | Where-Object Enabled
    $enabledCommands = $enabledFeatures.Commands
    $mappedCommands  = $script:DMFeatureState.Commands
    $unmappedExports = $Public.BaseName | Where-Object { $_ -notin $mappedCommands }
    $exportedCommands = @($enabledCommands) + @($unmappedExports) |
        Where-Object { $_ -in $Public.BaseName } |
        Select-Object -Unique

    $disabledFeatureNames = ($script:DMFeatureState | Where-Object { -not $_.Enabled }).Name
    if ($disabledFeatureNames) {
        Write-Verbose "POSH-Oceanstor disabled feature(s): $($disabledFeatureNames -join ', '). Use Enable-DMFeature + Import-Module -Force to expose their commands."
    }

#Only export aliases whose target command is itself being exported.
    $enabledAliases = (Get-Alias | Where-Object { $_.Definition -in $exportedCommands }).Name

Export-ModuleMember -Function $exportedCommands -Alias $enabledAliases
