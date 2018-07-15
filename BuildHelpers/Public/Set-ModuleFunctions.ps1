function Set-ModuleFunctions {
    <#
    .SYNOPSIS
        Set FunctionsToExport in a module manifest

    .FUNCTIONALITY
        CI/CD

    .DESCRIPTION
        Set FunctionsToExport in a module manifest

    .PARAMETER Name
        Path to module to inspect.  Defaults to ProjectPath\ProjectName via Get-BuildVariables

    .NOTES
        Major thanks to Joel Bennett for the code behind working with the psd1
            Source: https://github.com/PoshCode/Configuration

    .EXAMPLE
        Set-ModuleFunctions

    .LINK
        https://github.com/RamblingCookieMonster/BuildHelpers

    .LINK
        about_BuildHelpers
    #>
    [cmdletbinding()]
    param(
        [parameter(ValueFromPipeline = $True)]
        [Alias('Path')]
        [string]$Name,

        [string[]]$FunctionsToExport
    )

    Process
    {
        # cache the modules loaded before we start
        $loadedModules = Get-Module

        if(-not $Name)
        {
            $BuildDetails = Get-BuildVariables
            $Name = Join-Path ($BuildDetails.ProjectPath) (Get-ProjectName)
        }

        $Module = Import-Module -Name (Resolve-Path $Name).Path -PassThru -Force

        if(-not $Module)
        {
            Throw "Could not find module '$Name'"
        }
        if(-not $FunctionsToExport)
        {
            $FunctionsToExport = @( $Module.ExportedFunctions.Keys )
        }

        $Parent = $Module.ModuleBase
        $File = "$($Module.Name).psd1"
        $ModulePSD1Path = Join-Path $Parent $File
        if(-not (Test-Path $ModulePSD1Path))
        {
            Throw "Could not find expected module manifest '$ModulePSD1Path'"
        }

        Update-MetaData -Path $ModulePSD1Path -PropertyName FunctionsToExport -Value $FunctionsToExport

        # remove all modules no in the cache
        Get-Module |
            Where-Object { $_ -notin $loadedModules } |
            Foreach-Object { Remove-Module -ModuleInfo $_ -ErrorAction SilentlyContinue }
    }
}
