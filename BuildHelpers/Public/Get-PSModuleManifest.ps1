function Get-PSModuleManifest {
    <#
    .SYNOPSIS
        Get the PowerShell module manifest for a project

    .FUNCTIONALITY
        CI/CD

    .DESCRIPTION
        Get the PowerShell module manifest for a project

        Evaluates based on the following scenarios:
            * Subfolder with the same name as the current folder with a psd1 file in it
            * Subfolder with a <subfolder-name>.psd1 file in it
            * Current folder with a <currentfolder-name>.psd1 file in it
            + Subfolder called "Source" or "src" (not case-sensitive) with a psd1 file in it

        Note: This does not handle paths in the format Folder\ModuleName\Version\

    .PARAMETER Path
        Path to project root. Defaults to the current working path

    .NOTES
        We assume you are in the project root, for several of the fallback options

    .EXAMPLE
        Get-PSModuleManifest

    .LINK
        https://github.com/RamblingCookieMonster/BuildHelpers

    .LINK
        Get-BuildVariables

    .LINK
        Set-BuildEnvironment

    .LINK
        about_BuildHelpers
    #>
    [cmdletbinding()]
    param(
        $Path = $PWD.Path
    )

    $Path = ( Resolve-Path $Path ).Path

    $CurrentFolder = Split-Path $Path -Leaf
    $ExpectedPath = Join-Path -Path $Path -ChildPath $CurrentFolder
    $ExpectedManifest = Join-Path -Path $ExpectedPath -ChildPath "$CurrentFolder.psd1"
    if(Test-Path $ExpectedManifest)
    {
        $ExpectedManifest
    }
    else
    {
        # Look for properly organized modules
        $ProjectPaths = Get-ChildItem $Path -Directory | 
            ForEach-Object {
                $ThisFolder = $_
                $ExpectedManifest = Join-Path $ThisFolder.FullName "$($ThisFolder.Name).psd1"
                If( Test-Path $ExpectedManifest)
                {
                    $ExpectedManifest
                }
            }

        if( @($ProjectPaths).Count -gt 1 )
        {
            Write-Warning "Found more than one project path via subfolders with psd1 files"
            $ProjectPaths
        }
        elseif( @($ProjectPaths).Count -eq 1 )
        {
            $ProjectPaths
        }
        #PSD1 in root of project - ick, but happens.
        elseif( Test-Path "$ExpectedPath.psd1" )
        {
            "$ExpectedPath.psd1"
        }
        # PSD1 in Source or Src folder
        elseif( Get-Item "$Path\S*rc*\*.psd1" -OutVariable SourceManifests)
        {
            If ( $SourceManifests.Count -gt 1 )
            {
                Write-Warning "Found more than one project manifest in the Source folder"
            }
            $SourceManifests.FullName
        }
        else
        {
            Write-Warning "Could not find a PowerShell module manifest from $($Path)"
        }
    }
}