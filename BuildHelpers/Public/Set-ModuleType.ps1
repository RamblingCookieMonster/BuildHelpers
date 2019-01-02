function Set-ModuleType {
    <#
    .SYNOPSIS
        EXPIRIMENTAL: Set TypesToProcess

        [string]$TypesPath in a module manifest

    .FUNCTIONALITY
        CI/CD

    .DESCRIPTION
        EXPIRIMENTAL: Set TypesToProcess

        [string]$TypesPath in a module manifest

    .PARAMETER Name
        Name or path to module to inspect.  Defaults to ProjectPath\ProjectName via Get-BuildVariable

    .PARAMETER TypesToProcess
        Array of .ps1xml files

    .PARAMETER TypesRelativePath
        Path to the ps1xml files relatives to the root of the module (example: ".\Types")

    .NOTES
        Major thanks to Joel Bennett for the code behind working with the psd1
            Source: https://github.com/PoshCode/Configuration

    .EXAMPLE
        Set-ModuleType -TypesRelativePath '.\Types'

        Update module manifiest TypesToProcess parameters with all the .ps1xml present in the .\Types folder.

    .LINK
        https://github.com/RamblingCookieMonster/BuildHelpers

    .LINK
        about_BuildHelpers
    #>
    [CmdLetBinding( SupportsShouldProcess )]
    param(
        [parameter(ValueFromPipeline = $True)]
        [Alias('Path')]
        [string]$Name,

        [string[]]$TypesToProcess,

        [string]$TypesRelativePath
    )
    Process
    {
        if(-not $Name)
        {
            $BuildDetails = Get-BuildVariable
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

        if(-not $TypesToProcess)
        {
            $TypesPath = Join-Path -Path $Parent -ChildPath $TypesRelativePath
            $TypesList = Get-ChildItem -Path (Join-Path $TypesPath "*.ps1xml")

            $TypesToProcess = @()
            Foreach ($Item in $TypesList) {
                $TypesToProcess += Join-Path -Path $TypesRelativePath -ChildPath $Item.Name
            }
        }

        If ($PSCmdlet.ShouldProcess("Updating Module's TypesToProcess")) {
            Update-MetaData -Path $ModulePSD1Path -PropertyName TypesToProcess -Value $TypesToProcess
        }

        # Close down the runspace
        $PowerShell.Dispose()
    }
}
