function Set-BuildEnvironment {
    <#
    .SYNOPSIS
        Normalize build system and project details into variables

    .FUNCTIONALITY
        CI/CD

    .DESCRIPTION
        Normalize build system and project details into variables or environment variables

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

    .PARAMETER AsVariable
        If specified, set BH* PowerShell variables, rather than environment variables.

        Defaults to global scope.  Use Scope parameter to change this be

    .PARAMETER Scope
        When using AsVariable:

        Determines the scope of the variables. Valid values are "Global", "Local", or "Script", or a number 
        relative to the current scope (0 through the number of scopes, where 0 is the current scope and 1 is its 
        parent). "Local" is the default. For more information, see about_Scopes.
        
        Defaults to global

    .NOTES
        We assume you are in the project root, for several of the fallback options

    .EXAMPLE
        Set-BuildEnvironment
        Get-Item ENV:BH*

        # Set build environment variables as environment variables, read them

    .EXAMPLE
        Set-BuildEnvironment -AsVariable
        Get-Item variable:BH*

        # Set build environment variables as PowerShell variables, read them

    .EXAMPLE
        Set-BuildEnvironment -Scope 2
        Get-Variable -Name BH* -Scope 2

        # Set build environment variables as PowerShell variables, in the parent of the parent scope, read them

    .LINK
        https://github.com/RamblingCookieMonster/BuildHelpers

    .LINK
        Get-BuildVariables

    .LINK
        Get-ProjectName

    .LINK
        about_BuildHelpers
    #>
    [cmdletbinding(DefaultParameterSetName = 'ENV')]
    param(
        $Path = $PWD.Path,
        
        [parameter(ParameterSetName = 'VAR')]
        [switch]
        $AsVariable,

        [parameter(ParameterSetName = 'VAR')]
        [validatescript({
            if ( -not ( 'Global', 'Local', 'Script', 'Current' -contains $_ -or $_ -as [int] ) )
            {
                throw "'$_' is an invalid Scope. For more information, run Get-Help Set-BuildEnvironment -Parameter Scope"
            }
            $true
        })]
        [string]
        $Scope
    )
    $BuildVars = Get-BuildVariables -Path $Path
    $ProjectName = Get-ProjectName -Path $Path
    $ManifestPath = Get-PSModuleManifest -Path $Path

    if($PSCmdlet.ParameterSetName -eq 'ENV')
    {
        $ENV:BHBuildSystem = $BuildVars.BuildSystem
        $ENV:BHProjectPath = $BuildVars.ProjectPath
        $ENV:BHBranchName = $BuildVars.BranchName
        $ENV:BHCommitMessage = $BuildVars.CommitMessage
        $ENV:BHBuildNumber = $BuildVars.BuildNumber
        $ENV:BHProjectName = $ProjectName
        $ENV:BHPSModuleManifest = $ManifestPath
        $ENV:BHPSModulePath = Split-Path -Path $ManifestPath -Parent
    }
    else #VAR
    {
        $params = @{Scope = 'Global'}
        if($PSBoundParameters.ContainsKey($Scope))
        {
            $params['Scope'] = $Scope
        }
        Set-Variable @params -Name BHBuildSystem -Value $BuildVars.BuildSystem
        Set-Variable @params -Name BHProjectPath -Value $BuildVars.ProjectPath
        Set-Variable @params -Name BHBranchName -Value $BuildVars.BranchName
        Set-Variable @params -Name BHCommitMessage -Value $BuildVars.CommitMessage
        Set-Variable @params -Name BHBuildNumber -Value $BuildVars.BuildNumber
        Set-Variable @params -Name BHProjectName -Value $ProjectName
        Set-Variable @params -Name BHPSModuleManifest -Value $ManifestPath
        Set-Variable @params -Name BHPSModulePath -Value $(Split-Path -Path $ManifestPath -Parent)
    }
}