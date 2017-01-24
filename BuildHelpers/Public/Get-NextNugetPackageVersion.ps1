function Get-NextNugetPackageVersion {
    <#
    .SYNOPSIS
        Get the next version for a nuget package, such as a module or script in the PowerShell Gallery

    .FUNCTIONALITY
        CI/CD

    .DESCRIPTION
        Get the next version for a nuget package, such as a module or script in the PowerShell Gallery

        Uses the versioning scheme adopted by the user

        Where possible, users should stick to semver: http://semver.org/ (Major.Minor.Patch, given restrictions .NET Version class)
        
        If no existing module is found, we return 0.0.1

    .PARAMETER Name
        Name of the nuget package

    .PARAMETER PackageSourceUrl
        Nuget PackageSourceUrl to query.
            PSGallery Module URL: https://www.powershellgallery.com/api/v2/ (default)
            PSGallery Script URL: https://www.powershellgallery.com/api/v2/items/psscript/

    .EXAMPLE
        Get-NextNugetPackageVersion PSDeploy

    .EXAMPLE
        Get-NextNugetPackageVersion Open-ISEFunction -PackageSourceUrl https://www.powershellgallery.com/api/v2/items/psscript/

    .LINK
        https://github.com/RamblingCookieMonster/BuildHelpers

    .LINK
        about_BuildHelpers
    #>
    [cmdletbinding()]
    param(
        [parameter(ValueFromPipelineByPropertyName=$True)]
        [string[]]$Name,

        [string]$PackageSourceUrl = 'https://www.powershellgallery.com/api/v2/'
    )
    Process
    {
        foreach($Item in $Name)
        {
            Try
            {
                $Existing = $null
                $Existing = Find-NugetPackage -Name $Item -PackageSourceUrl $PackageSourceUrl -IsLatest -ErrorAction Stop
            }
            Catch
            {
                if($_ -match "No match was found for the specified search criteria")
                {
                    New-Object System.Version (0,0,1)
                }
                else
                {
                    Write-Error $_
                }
                continue
            }

            if($Existing.count -gt 1)
            {
                Write-Error "Found more than one $Type matching '$Item': Did you use a wildcard?"
                continue
            }
            elseif($Existing.count -eq 0)
            {
                Write-Verbose "Found no $Type matching '$Item'"
                New-Object System.Version (0,0,1)
                continue
            }
            else
            {
                $Version = [System.Version]$Existing.Version
            }

            # using revision
            if($Version.Revision -ge 0)
            {
                $Build = if($Version.Build -le 0) { 0 } else { $Version.Build }
                $Revision = if($Version.Revision -le 0) { 1 } else { $Version.Revision + 1 }
                New-Object System.Version ($Version.Major, $Version.Minor, $Build, $Revision)
            }
            # using build
            elseif($Version.Build -ge 0)
            {
                $Build = if($Version.Build -le 0) { 1 } else { $Version.Build + 1 }
                New-Object System.Version ($Version.Major, $Version.Minor, $Build)
            }
            # using minor. wat?
            elseif($Version.Minor -ge 0)
            {
                $Minor = if($Version.Minor -le 0) { 1 } else { $Version.Minor + 1 }
                New-Object System.Version ($Version.Major, $Minor)
            }
            # using major only. I don't even.
            else
            {
                New-Object System.Version ($Version.Major + 1, 0)
            }
        }
    }
}
