function Get-ModuleFunctions {
    <#
    .SYNOPSIS
        List functions imported by a module

    .FUNCTIONALITY
        CI/CD

    .DESCRIPTION
        List functions imported by a module. Note that this actually imports the module.

    .PARAMETER Name
        Name or path to module to inspect.  Defaults to ProjectPath\ProjectName

    .NOTES
        We assume you are in the project root, for several of the fallback options

    .EXAMPLE
        Get-ModuleFunctions

    .LINK
        https://github.com/RamblingCookieMonster/BuildHelpers

    .LINK
        about_BuildHelpers
    #>
    [cmdletbinding()]
    param(
        [parameter(ValueFromPipeline = $True)]
        [Alias('Path')]
        [string]$Name
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
            Import-Module -Name $Name -PassThru:$Passthru -Force:$Force

        }).AddParameters($Params)

        ( $PowerShell.Invoke() ).ExportedFunctions.Keys

        $PowerShell.Dispose()
    }
}