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
        [Parameter(Position=0,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   HelpMessage="Path to one or more locations.")]
        [Alias("PSPath")]
        [ValidateScript({if (Test-ModuleManifest $_) {$true} else {$false} })]
        [string[]]
        $Path,
        
        # Version section to step
        [Parameter(Position=1)]
        [ValidateSet("Major", "Minor", "Build","Patch")]
        [Alias("Type")]
        [string]
        $By = "Patch"
    )
    
    Begin 
    {
        if (-not $PSBoundParameters.ContainsKey("Path"))
        {
            $Path = (Get-Item $PWD\*.psd1)[0]
        }                
    }
    
    Process
    {
        foreach ($file in $Path)
        {
            if (-not (Test-ModuleManifest -Path $file))
            {
                Write-Error -Exception $Error[0].Exception
                continue
            }
            
            $manifest = Import-PowerShellDataFile -Path $file 
            $newVersion = Step-Version $manifest.ModuleVersion $By
            $manifest.Remove("ModuleVersion")
                   
            $manifest.FunctionsToExport = $manifest.FunctionsToExport | ForEach-Object {$_}
            $manifest.NestedModules = $manifest.NestedModules | ForEach-Object {$_}
            $manifest.RequiredModules = $manifest.RequiredModules | ForEach-Object {$_}
            $manifest.ModuleList = $manifest.ModuleList | ForEach-Object {$_}
            
            foreach ($node in $manifest.PrivateData["PSData"].GetEnumerator())
            {
                $key = $node.Key
                if ($node.Value.GetType().Name -eq "Object[]")
                {
                    $value = $node.Value | ForEach-Object {$_}
                }
                else 
                {
                    $value = $node.Value    
                }
                
                $manifest[$key] = $value
            }
            $manifest.Remove("PrivateData")
            
            New-ModuleManifest -Path $file -ModuleVersion $newVersion @manifest
        }   
    }    
}
