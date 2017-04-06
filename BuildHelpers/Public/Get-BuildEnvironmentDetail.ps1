function Get-BuildEnvironmentDetail {
    <#
    .SYNOPSIS
        Get the details on the build environment

    .FUNCTIONALITY
        CI/CD

    .DESCRIPTION
        Get the details on the build environment.  You might use this to debug a build, particularly in environments not under your control.

    .PARAMETER Detail
        Which build environment details to collect.

        Defaults to *

        Valid choices:
          'OperatingSystem'  Subset of win32_operatingsystem
          'PSVersionTable'   Variable
          'ModulesLoaded'    Get-Module
          'ModulesAvailable' Get-Module -ListAvailable
          'PSModulePath'     ENV:
          'Path'             ENV:
          'Variables'        Get-Variable
          'Software'         Get-InstalledSoftware
          'Hotfixes'         Get-Hotfix
          'Location'         Get-Location
          'PackageProvider'  Get-PackageProvider
          'PackageSource'    Get-PackageSource

    .PARAMETER KillKittens
        If specified, apply formatting to the output (bad) and sent some of it to the host (worse)

    .EXAMPLE
        Get-BuildEnvironmentDetail

    .LINK
        https://github.com/RamblingCookieMonster/BuildHelpers

    .LINK
        about_BuildHelpers
    #>
    [cmdletbinding()]
    param(
        [validateset('*',
                     'OperatingSystem',
                     'PSVersionTable',
                     'ModulesLoaded',
                     'ModulesAvailable',
                     'PSModulePath',
                     'Path',
                     'Variables',
                     'Software',
                     'Hotfixes',
                     'Location',
                     'PackageProvider',
                     'PackageSource')]
        [string[]]$Detail = '*',
        [switch]$KillKittens
    )

    if($Detail -contains '*')
    {
        $Detail =  'OperatingSystem',
                   'PSVersionTable',
                   'ModulesLoaded',
                   'ModulesAvailable',
                   'PSModulePath',
                   'Path',
                   'Variables',
                   'Software',
                   'Hotfixes',
                   'Location',
                   'PackageProvider',
                   'PackageSource'
    }

    $Details = @{}
    switch ($Detail)
    {
        'PSVersionTable'   { $Details.set_item($_, $PSVersionTable)}
        'PSModulePath'     { $Details.set_item($_, ($ENV:PSModulePath -split ';'))}
        'ModulesLoaded'    { $Details.set_item($_, ( 
            Get-Module |
                Select Name, Version, Path |
                Sort Name
        )) }
        'ModulesAvailable' { $Details.set_item($_, (
            Get-Module -ListAvailable |
                Select Name, Version, Path |
                Sort Name            
        
        )) }
        'Path'             { $Details.set_item($_, ( $ENV:Path -split ';'))}
        'Variables'        { $Details.set_item($_, ( Get-Variable | Select Name, Value ))}       
        'Software'         { $Details.set_item($_, (
            Get-InstalledSoftware |
                Select DisplayName, Publisher, Version, Hive, Arch))}
        'Hotfixes'         { $Details.set_item($_, ( Get-Hotfix ))}
        'OperatingSystem'  { $Details.set_item($_, (
            Get-WMIObject win32_operatingsystem |
                Select Caption,
                       Version
        ))}
        'Location'         { $Details.set_item($_, ( Get-Location ).Path )}
        'PackageProvider'  { $Details.set_item($_, $(
            if(Get-Module PackageManagement -ListAvailable)
            {
                Get-PackageProvider | Select Name, Version
            }
         ))}
        'PackageSource'    { $Details.set_item($_, $(
            if(Get-Module PackageManagement -ListAvailable)
            {
                Get-PackageSource | Select Name, ProviderName, Location
            }
         ))}
    }

    if($KillKittens)
    {
        $lines = '----------------------------------------------------------------------'
        foreach($Key in $Details.Keys)
        {
            "`n$lines`n$Key`n`n"
            $Details.get_item($key) | Out-Host
        }
    }
    else
    {
        $Details
    }
}