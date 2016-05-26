# Grab nuget bits, install modules, start build.
Get-PackageProvider -Name NuGet -ForceBootstrap

Install-Module Psake, PSDeploy, Pester, BuildHelpers -force

Import-Module Psake, BuildHelpers
Set-BuildEnvironment

Invoke-psake .\psake.ps1