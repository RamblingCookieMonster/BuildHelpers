<#
.SYNOPSIS
    Increments the ModuleVersion property in a PowerShell Module Manfiest
.DESCRIPTION
    Reads an existing Module Manifest file and increments the ModuleVersion property.
.EXAMPLE
    C:\PS> Step-ModuleVersion -Path .\testmanifest.psd1

    Will increment the Build section of the ModuleVersion
.EXAMPLE
    C:\PS> Step-ModuleVersion -Path .\testmanifest.psd1 -By Minor

    Will increment the Minor section of the ModuleVersion and set the Build section to 0.
.EXAMPLE
    C:\PS> Set-Location C:\source\testmanifest
    C:\PS> Step-ModuleVersion

    Will increment the Build section of the ModuleVersion of the manifest in the current
    working directory.
.INPUTS
    String
.NOTES
    This function should only read the module and call Update-ModuleManifest with
    the new Version, but there appears to be a bug in Update-ModuleManifest dealing
    with Object[] types so this function manually de-serializes the manifest and
    calls New-ModuleManifest to overwrite the manifest at Path.
.LINK
    http://semver.org/
.LINK
    New-ModuleManifest
#>
function Step-ModuleVersion {
    [CmdletBinding()]
    param(
        # Specifies a path a valid Module Manifest file.
        [Parameter(ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   HelpMessage="Path to one or more locations.")]
        [Alias("PSPath")]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string[]]
        $Path = (Get-Item $PWD\*.psd1)[0],

        # Version section to step
        [Parameter()]
        [ValidateSet("Major", "Minor", "Build","Patch")]
        [Alias("Type")]
        [string]
        $By = "Patch"
    )

    Process
    {
        foreach ($file in $Path)
        {
            $version = [Version](Get-Metadata -Path $file)
            Update-MetaData -Path $file -PropertyName ModuleVersion -Value (Step-Version $version $By)
        }
    }
}
