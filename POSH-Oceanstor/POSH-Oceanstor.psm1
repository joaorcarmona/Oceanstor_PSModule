# developed originally by Warren Frame "RamblingCookieMonster" (https://github.com/RamblingCookieMonster)

#Load the session class first so other classes can reference [OceanstorSession] in their constructors.
    . $PSScriptRoot\Private\class-OceanstorSession.ps1

#Get public and private function definition files.
    $Public  = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue )
    $Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue |
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

Export-ModuleMember -Function $Public.Basename
