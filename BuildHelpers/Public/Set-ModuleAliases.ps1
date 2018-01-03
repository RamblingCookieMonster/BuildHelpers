function Set-ModuleAliases {
    <#
    .SYNOPSIS
        EXPIRIMENTAL: Set AliasesToExport in a module manifest

    .FUNCTIONALITY
        CI/CD

    .DESCRIPTION
        EXPIRIMENTAL: Set AliasesToExport in a module manifest

    .PARAMETER Name
        Name or path to module to inspect.  Defaults to ProjectPath\ProjectName via Get-BuildVariables

    .NOTES
        Major thanks to Joel Bennett for the code behind working with the psd1
            Source: https://github.com/PoshCode/Configuration

    .EXAMPLE
        Set-ModuleAliases

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

        [string[]]$AliasesToExport
    )
    Process
    {
        if(-not $Name)
        {
            $BuildDetails = Get-BuildVariables
            $Name = Join-Path ($BuildDetails.ProjectPath) (Get-ProjectName)
        }

        $params = @{
            Force = $True
            Passthru = $True
            Name = $Name
        }

        # Create a runspace, add script to run
        $PowerShell = [Powershell]::Create()
        [void]$PowerShell.AddScript({
            Param ($Force, $Passthru, $Name)
            $module = Import-Module -Name $Name -PassThru:$Passthru -Force:$Force
            $module | Where-Object Path -notin $module.Scripts

        }).AddParameters($Params)

        #Consider moving this to a runspace or job to keep session clean
        $Module = $PowerShell.Invoke()
        if(-not $Module)
        {
            Throw "Could not find module '$Name'"
        }

        if(-not $AliasesToExport)
        {
            $AliasesToExport = @( $Module.ExportedAliases.Keys )
        }

        $Parent = $Module.ModuleBase
        $File = "$($Module.Name).psd1"
        $ModulePSD1Path = Join-Path $Parent $File
        if(-not (Test-Path $ModulePSD1Path))
        {
            Throw "Could not find expected module manifest '$ModulePSD1Path'"
        }

        Update-MetaData -Path $ModulePSD1Path -PropertyName AliasesToExport -Value $AliasesToExport
        
        # Close down the runspace
        $PowerShell.Dispose()
    }
}