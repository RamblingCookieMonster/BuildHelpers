function Set-ModuleFormats {
    <#
    .SYNOPSIS
        EXPIRIMENTAL: Set FormatsToProcess
        
        [string]$FormatsPath in a module manifest

    .FUNCTIONALITY
        CI/CD

    .DESCRIPTION
        EXPIRIMENTAL: Set FormatsToProcess
        
        [string]$FormatsPath in a module manifest

    .PARAMETER Name
        Name or path to module to inspect.  Defaults to ProjectPath\ProjectName via Get-BuildVariables

    .PARAMETER FormatsToProcess
        Array of .ps1xml files

    .PARAMETER FormatsRelativePath
        Path to the ps1xml files relatives to the root of the module (example: ".\Format")

    .NOTES
        Major thanks to Joel Bennett for the code behind working with the psd1
            Source: https://github.com/PoshCode/Configuration

    .EXAMPLE
        Set-ModuleFormats -FormatsRelativePath '.\Format'

        Update module manifiest FormatsToProcess parameters with all the .ps1xml present in the .\Format folder. 

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

        [string[]]$FormatsToProcess,

        [string]$FormatsRelativePath
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

        # Create a runspace
        $PowerShell = [Powershell]::Create()

        # Add scriptblock to the runspace
        [void]$PowerShell.AddScript({
            Param ($Force, $Passthru, $Name)
            $module = Import-Module -Name $Name -PassThru:$Passthru -Force:$Force
            $module | Where-Object Path -notin $module.Scripts

        }).AddParameters($Params)

        #Invoke the command
        $Module = $PowerShell.Invoke()

        if(-not $Module)
        {
            Throw "Could not find module '$Name'"
        }

        $Parent = $Module.ModuleBase
        $File = "$($Module.Name).psd1"
        $ModulePSD1Path = Join-Path $Parent $File
        if(-not (Test-Path $ModulePSD1Path))
        {
            Throw "Could not find expected module manifest '$ModulePSD1Path'"
        }

        if(-not $FormatsToProcess)
        {
            $FormatPath = Join-Path -Path $Parent -ChildPath $FormatsRelativePath
            $FormatList = Get-ChildItem -Path $FormatPath\*.ps1xml

            $FormatsToProcess = @()
            Foreach ($Item in $FormatList) {
                $FormatsToProcess += Join-Path -Path $FormatsRelativePath -ChildPath $Item.Name
            }
        }

        Update-MetaData -Path $ModulePSD1Path -PropertyName FormatsToProcess -Value $FormatsToProcess

        # Close down the runspace
        $PowerShell.Dispose()
    }
}