function Set-ModuleFunctions {
    <#
    .SYNOPSIS
        EXPIRIMENTAL: Set FunctionsToExport in a module manifest

    .FUNCTIONALITY
        CI/CD

    .DESCRIPTION
        EXPIRIMENTAL: Set FunctionsToExport in a module manifest

        WARNING:
            We...
                Deserialize your PSD1 file
                Update the FunctionsToExport
                Re-serialize via New-ModuleManifest

            Your comments will be lost in this, and there is a chance
            that serialization may mangle or miss items.

    .PARAMETER Name
        Name or path to module to inspect.  Defaults to ProjectPath\ProjectName

    .NOTES
        Major thanks to Joel Bennett for the code behind writing the new PrivateData
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

        $Module = ( Import-Module @params )
        if(-not $Module)
        {
            Throw "Could not find module '$Name'"
        }

        if(-not $FunctionsToExport)
        {
            $FunctionsToExport = @( $Module.ExportedCommands.Keys )
        }

        $Parent = $Module.ModuleBase
        $File = "$($Module.Name).psd1"
        $ModulePSD1Path = Join-Path $Parent $File
        if(-not (Test-Path $ModulePSD1Path))
        {
            Throw "Could not find expected module manifest '$ModulePSD1Path'"
        }

        $ModuleManifest = Import-LocalizedData -BaseDirectory $Parent -FileName $File
        If(-not $ModuleManifest)
        {
            Throw "Could not import module manifest from '$ModulePSD1Path'"
        }
        $ModuleManifest.FunctionsToExport = $FunctionsToExport
        $PrivateData = ConvertTo-Metadata $ModuleManifest.PrivateData
        $ModuleManifest.PrivateData = 'Ze Private Data!1'
        New-ModuleManifest @ModuleManifest -Path $ModulePSD1Path -WarningAction SilentlyContinue
        $ManifestText = Get-Content $ModulePSD1Path -Raw
        $ManifestText = $ManifestText -replace "'Ze Private Data!1'", $PrivateData
        Out-File -FilePath $ModulePSD1Path -InputObject $ManifestText
    }
}