function Set-BuildEnvironment {
    <#
    .SYNOPSIS
        Normalize build system and project details into environment variables

    .FUNCTIONALITY
        CI/CD

    .DESCRIPTION
        Normalize build system and project details into environment variables

        Creates the following environment variables:
            $ENV:BHProjectPath      via Get-BuildVariables
            $ENV:BHBranchName       via Get-BuildVariables
            $ENV:BHCommitMessage    via Get-BuildVariables
            $ENV:BHBuildNumber      via Get-BuildVariables
            $ENV:BHProjectName      via Get-ProjectName
            $ENV:BHPSModuleManifest via Get-PSModuleManifest
            $ENV:BHPSModulePath     via Split-Path on BHPSModuleManifest

    .PARAMETER Path
        Path to project root. Defaults to the current working path

    .PARAMETER VariableNamePrefix
        Allow to set a custom Prefix to the Environment variable created. The default is BH such as $Env:BHProjectPath

    .PARAMETER Passthru
        If specified, include output of the build variables we create

    .PARAMETER Force
        Overrides the Environment Variables even if they exist already

    .NOTES
        We assume you are in the project root, for several of the fallback options

    .EXAMPLE
        Set-BuildEnvironment

        Get-Item ENV:BH*

    .EXAMPLE
        Set-BuildEnvironment -VariableNamePrefix '' -Force

        Get-Item ENV:*

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

        [ValidatePattern('\w*')]
        [String]
        $VariableNamePrefix = 'BH',

        [switch]
        $Force
    )

    ${Build.Vars} = Get-BuildVariables -Path $Path
    ${Build.ProjectName} = Get-ProjectName -Path $Path
    ${Build.ManifestPath} = Get-PSModuleManifest -Path $Path
    if( ${Build.ManifestPath} )
    {
        ${Build.ModulePath} = Split-Path -Path ${Build.ManifestPath} -Parent
    }
    $BuildHelpersVariables = @{
        BuildSystem = ${Build.Vars}.BuildSystem
        ProjectPath = ${Build.Vars}.ProjectPath
        BranchName  = ${Build.Vars}.BranchName
        CommitMessage = ${Build.Vars}.CommitMessage
        BuildNumber = ${Build.Vars}.BuildNumber
        ProjectName = ${Build.ProjectName}
        PSModuleManifest = ${Build.ManifestPath}
        PSModulePath = ${Build.ModulePath}
    }
    foreach ($VarName in $BuildHelpersVariables.Keys) {
        if($null -ne $BuildHelpersVariables[$VarName]) {
            $Output = New-Item -Path Env:\ -Name ('{0}{1}' -f $VariableNamePrefix,$VarName) -Value $BuildHelpersVariables[$VarName] -Force:$Force
            if($Passthru)
            {
                $Output
            }
        }
    }
}