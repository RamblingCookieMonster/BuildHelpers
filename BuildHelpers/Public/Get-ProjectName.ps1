function Get-ProjectName
{
    <#
    .SYNOPSIS
        Get the name for this project

    .FUNCTIONALITY
        CI/CD

    .DESCRIPTION
        Get the name for this project

        Evaluates based on the following scenarios:
            * Subfolder with the same name as the current folder
            * Subfolder with a <subfolder-name>.psd1 file in it
            * Current folder with a <currentfolder-name>.psd1 file in it
            + Subfolder called "Source" or "src" (not case-sensitive) with a psd1 file in it

        If no suitable project name is discovered, the function will return
        the name of the root folder as the project name.

    .PARAMETER Path
        Path to project root. Defaults to the current working path

    .NOTES
        We assume you are in the project root, for several of the fallback options

    .EXAMPLE
        Get-ProjectName

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
    if(Test-Path $ExpectedPath)
    {
        $result = $CurrentFolder
    }
    else
    {
        # Look for properly organized modules
        $ProjectPaths = Get-ChildItem $Path -Directory |
            Where-Object {
            Test-Path $(Join-Path $_.FullName "$($_.name).psd1")
        } |
            Select -ExpandProperty Fullname

        if( @($ProjectPaths).Count -gt 1 )
        {
            Write-Warning "Found more than one project path via subfolders with psd1 files"
            $result = Split-Path $ProjectPaths -Leaf
        }
        elseif( @($ProjectPaths).Count -eq 1 )
        {
            $result = Split-Path $ProjectPaths -Leaf
        }
        #PSD1 in root of project - ick, but happens.
        elseif( Test-Path "$ExpectedPath.psd1" )
        {
            $result = $CurrentFolder
        }
        # PSD1 in Source or Src folder
        elseif( Get-Item "$Path\S*rc*\*.psd1" -OutVariable SourceManifests)
        {
            If ( $SourceManifests.Count -gt 1 )
            {
                Write-Warning "Found more than one project manifest in the Source folder"
            }
            $result = $SourceManifests.BaseName
        }
        else
        {
            Write-Warning "Could not find a project from $($Path); defaulting to project root for name"
            $result = Split-Path $Path -Leaf
        }
    }
    
    if ($env:APPVEYOR_PROJECT_NAME -and $env:APPVEYOR_JOB_ID -and ($result -like $env:APPVEYOR_PROJECT_NAME))
    {
        $env:APPVEYOR_PROJECT_NAME
    }
    else
    {
        $result
    }
}
