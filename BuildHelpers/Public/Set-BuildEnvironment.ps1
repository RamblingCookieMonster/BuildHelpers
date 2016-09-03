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

    .NOTES
        We assume you are in the project root, for several of the fallback options

    .EXAMPLE
        Set-BuildEnvironment

        Get-Item ENV:BH*

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
        $Path = $PWD.Path
    )

    $BuildVars = Get-BuildVariables -Path $Path
    $ProjectName = Get-ProjectName -Path $Path
    $ManifestPath = Get-PSModuleManifest -Path $Path

    $ENV:BHBuildSystem = $BuildVars.BuildSystem
    $ENV:BHProjectPath = $BuildVars.ProjectPath
    $ENV:BHBranchName = $BuildVars.BranchName
    $ENV:BHCommitMessage = $BuildVars.CommitMessage
    $ENV:BHBuildNumber = $BuildVars.BuildNumber
    $ENV:BHProjectName = $ProjectName
    $ENV:BHPSModuleManifest = $ManifestPath
    $ENV:BHPSModulePath = Split-Path -Path $ManifestPath -Parent -ErrorAction SilentlyContinue

}