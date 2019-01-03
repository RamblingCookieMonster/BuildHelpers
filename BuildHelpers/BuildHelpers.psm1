#Get public and private function definition files.
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

Export-ModuleMember -Function $Public.Basename

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
