# All credit and major props to Joel Bennett for this simplified solution that doesn't depend on PowerShellGet
# https://gist.github.com/Jaykul/1caf0d6d26380509b04cf4ecef807355
function Find-NugetPackage {
    <#
    .SYNOPSIS
        Query a Nuget feed for details on a package

    .FUNCTIONALITY
        CI/CD

    .DESCRIPTION
        Query a Nuget feed for details on a package

        We return:
            Name
            Author
            Version
            Uri
            Description
            Properties (A collection of even more properties)

    .PARAMETER Name
        Name of the nuget package

    .PARAMETER IsLatest
        Only return the latest package

    .PARAMETER Version
        Query this specific version of a package.  Superceded by IsLatest

    .PARAMETER PackageSourceUrl
        Nuget PackageSourceUrl to query.
            PSGallery Module URL: https://www.powershellgallery.com/api/v2/ (default)
            PSGallery Script URL: https://www.powershellgallery.com/api/v2/items/psscript/

    .EXAMPLE
        Find-NugetPackage PSDepend -IsLatest

        # Get details on the latest PSDepend package from the PowerShell Gallery

    .EXAMPLE
        Find-NugetPackage Open-ISEFunction -PackageSourceUrl https://www.powershellgallery.com/api/v2/items/psscript/

        # Get details on the latest Open-ISEFunction package from the PowerShell Gallery scripts URI

    .EXAMPLE
        Find-NugetPackage PSDeploy

        # Get a list of every PSDeploy release on the PowerShell gallery feed

    .LINK
        https://github.com/RamblingCookieMonster/BuildHelpers

    .LINK
        about_BuildHelpers
    #>
    [CmdletBinding()]
    param(
        # The name of a package to find
        [Parameter(Mandatory)]
        $Name,
        # The repository api URL -- like https://www.powershellgallery.com/api/v2/ or https://www.nuget.org/api/v2/
        $PackageSourceUrl = 'https://www.powershellgallery.com/api/v2/',

        #If specified takes precedence over version
        [switch]$IsLatest,

        [string]$Version
    )

    #Ugly way to do this.  Prefer islatest, otherwise look for version, otherwise grab all matching modules
    if($IsLatest)
    {
        Write-Verbose "Searching for latest [$name] module"
        $URI = Join-Parts -Separator / -Parts $PackageSourceUrl, "Packages?`$filter=Id eq '$name' and IsLatestVersion"
    }
    elseif($PSBoundParameters.ContainsKey($Version))
    {
        Write-Verbose "Searching for version [$version] of [$name]"
        $URI = Join-Parts -Separator / -Parts $PackageSourceUrl, "Packages?`$filter=Id eq '$name' and Version eq '$Version'"
    }
    else
    {
        Write-Verbose "Searching for all versions of [$name] module"
        $URI = Join-Parts -Separator / -Parts $PackageSourceUrl ,"Packages?`$filter=Id eq '$name'"
    }

    Invoke-RestMethod $URI | 
    Select-Object @{n='Name';ex={$_.title.('#text')}},
                  @{n='Author';ex={$_.author.name}},
                  @{n='Version';ex={$_.properties.NormalizedVersion}},
                  @{n='Uri';ex={$_.Content.src}},
                  @{n='Description';ex={$_.properties.Description}},
                  @{n='Properties';ex={$_.properties}}
}
