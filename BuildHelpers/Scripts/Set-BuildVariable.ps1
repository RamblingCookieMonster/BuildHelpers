<#
.SYNOPSIS
    Normalize build system and project details into variables

.FUNCTIONALITY
    CI/CD

.DESCRIPTION
    Normalize build system and project details into variables

    Creates the following variables:
        BHProjectPath      via Get-BuildVariables
        BHBranchName       via Get-BuildVariables
        BHCommitMessage    via Get-BuildVariables
        BHBuildNumber      via Get-BuildVariables
        BHProjectName      via Get-ProjectName
        BHPSModuleManifest via Get-PSModuleManifest
        BHPSModulePath     via Split-Path on BHPSModuleManifest

.PARAMETER Path
    Path to project root. Defaults to the current working path

.PARAMETER Scope
    Determines the scope of the variables. Valid values are "Global", "Local", or "Script", or a number
    relative to the current scope (0 through the number of scopes, where 0 is the current scope and 1 is its
    parent). For more information, see about_Scopes.

    Defaults to the calling scope, 0 if it is dot-sourced, 1 if it is invoked normally.

    The scope value Script may only be used with dot-sourced Set-BuildVariable.

.NOTES
    We assume you are in the project root, for several of the fallback options

.EXAMPLE
    Set-BuildVariable
    Get-Variable BH* -Scope 0

    # Set build variables in the current scope, read them

.EXAMPLE
    . Set-BuildVariable -Scope Script
    Get-Variable BH* -Scope Script

    # Set build variables in the script scope (mind the .), read them

.LINK
    https://github.com/RamblingCookieMonster/BuildHelpers

.LINK
    Get-BuildVariables

.LINK
    Get-ProjectName

.LINK
    about_BuildHelpers
#>
[cmdletbinding()]
param(
    $Path = $PWD.Path,

    [validatescript({
        if(-not ('Global', 'Local', 'Script', 'Current' -contains $_ -or (($_ -as [int]) -ge 0)))
        {
            throw "'$_' is an invalid Scope. For more information, run Get-Help Set-BuildVariable -Parameter Scope"
        }
        $true
    })]
    [string]
    $Scope
)

if($MyInvocation.InvocationName -eq '.')
{
    if(-not $Scope)
    {
        $Scope = '0'
    }
}
else
{
    if($Scope -eq 'Script')
    {
        throw 'The script scope may only be used with dot-sourced Set-BuildVariable.'
    }
    if(-not $Scope)
    {
        $Scope = '1'
    }
}

${Build.Vars} = Get-BuildVariables -Path $Path
${Build.ProjectName} = Get-ProjectName -Path $Path
${Build.ManifestPath} = Get-PSModuleManifest -Path $Path

Set-Variable -Scope $Scope -Name BHBuildSystem -Value ${Build.Vars}.BuildSystem
Set-Variable -Scope $Scope -Name BHProjectPath -Value ${Build.Vars}.ProjectPath
Set-Variable -Scope $Scope -Name BHBranchName -Value ${Build.Vars}.BranchName
Set-Variable -Scope $Scope -Name BHCommitMessage -Value ${Build.Vars}.CommitMessage
Set-Variable -Scope $Scope -Name BHBuildNumber -Value ${Build.Vars}.BuildNumber
Set-Variable -Scope $Scope -Name BHProjectName -Value ${Build.ProjectName}
Set-Variable -Scope $Scope -Name BHPSModuleManifest -Value ${Build.ManifestPath}
Set-Variable -Scope $Scope -Name BHPSModulePath -Value $(Split-Path -Path ${Build.ManifestPath} -Parent)
