#Get public and private function definition files.
$Public  = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue )
$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue )
# $ModuleRoot = $PSScriptRoot

#Dot source the files
Foreach($import in @($Public + $Private))
{
    Try
    {
        . $import.fullname
    }
    Catch
    {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}

# Load dependencies. TODO: Move to module dependency once the bug that
# causes this is fixed: https://ci.appveyor.com/project/RamblingCookieMonster/buildhelpers/build/1.0.22
# Thanks to Joel Bennett for this!
$fallbackModule = Get-Module -Name $PSScriptRoot\Private\Modules\Configuration -ListAvailable
if ($configModule = Get-Module $fallbackModule.Name -ListAvailable)
{
    $configModule |
        Where-Object { $_.Version -gt $fallbackModule.Version} |
        Sort-Object -Property Version -Descending |
        Select-Object -First 1 |
        Import-Module -Force
}
if (-not (Get-Module $fallbackModule.Name | Where-Object { $_.Version -gt $fallbackModule.Version}))
{
    $fallbackModule | Import-Module -Force
}

Export-ModuleMember -Function $Public.Basename
Export-ModuleMember -Function Get-Metadata, Update-Metadata, Export-Metadata

# Set aliases (#10)
Set-Alias -Name Set-BuildVariable -Value $PSScriptRoot\Scripts\Set-BuildVariable.ps1
Set-Alias -Name Get-NextPSGalleryVersion -Value Get-NextNugetPackageVersion
# Backwards compatibilty to command names prior to #72
Set-Alias -Name Get-BuildVariables -Value Get-BuildVariable
Set-Alias -Name Get-ModuleAliases -Value Get-ModuleAlias
Set-Alias -Name Get-ModuleFunctions -Value Get-ModuleFunction
Set-Alias -Name Set-ModuleAliases -Value Set-ModuleAlias
Set-Alias -Name Set-ModuleFormats -Value Set-ModuleFormat
Set-Alias -Name Set-ModuleFunctions -Value Set-ModuleFunction
Set-Alias -Name Set-ModuleTypes -Value Set-ModuleType

$exportModuleMemberSplat = @{
    Alias = @(
        'Set-BuildVariable'
        'Get-NextPSGalleryVersion'
        'Get-BuildVariables'
        'Get-ModuleAliases'
        'Get-ModuleFunctions'
        'Set-ModuleAliases'
        'Set-ModuleFormats'
        'Set-ModuleFunctions'
        'Set-ModuleTypes'
    )
}
Export-ModuleMember @exportModuleMemberSplat
