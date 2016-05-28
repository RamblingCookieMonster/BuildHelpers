<#
.SYNOPSIS
    Increment a Semantic Version
.DESCRIPTION
    Parse a string in the format of MAJOR.MINOR.PATCH and increment the
    selected digit.
.EXAMPLE
    C:\PS> Step-Version 1.1.1
    1.1.2
    
    Will increment the Patch/Build section of the Version
.EXAMPLE
    C:\PS> Step-Version 1.1.1 Minor
    1.2.0
    
    Will increment the Minor section of the Version
.EXAMPLE
    C:\PS> Step-Version 1.1.1 Major
    2.0.0
    
    Will increment the Major section of the Version    
.EXAMPLE
    C:\PS> $v = [version]"1.1.1"
    C:\PS> $v | Step-Version -Type Minor
    1.2.0
.INPUTS
    String
.OUTPUTS
    String    
.NOTES
    This function operates on strings.
#>
function Step-Version {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        # Version as string to increment
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   Position=0)]
        [String]
        $Version,
        
        # Version section to step
        [Parameter(Position=1)]
        [ValidateSet("Major", "Minor", "Build","Patch")]
        [Alias("Type")]
        [string]
        $By = "Patch"
    )

    Process
    {
        $currentVersion = [version]$Version
        
        $major = $currentVersion.Major
        $minor = $currentVersion.Minor
        $build = $currentVersion.Build
        
        switch ($By) {
            "Major" { $major++
                    $minor = 0
                    $build = 0
                    break }
            "Minor" { $minor++
                    $build = 0
                    break }
            Default { $build++
                    break }
        }
        
        $newVersion = New-Object Version -ArgumentList $major, $minor, $build

        Write-Output -InputObject $newVersion.ToString()
    }  
}

