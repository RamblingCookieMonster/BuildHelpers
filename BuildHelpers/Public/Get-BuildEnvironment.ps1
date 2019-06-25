function Get-BuildEnvironment {
    <#
    .SYNOPSIS
        Get normalized build system and project details

    .FUNCTIONALITY
        CI/CD

    .DESCRIPTION
        Get normalized build system and project details

        Returns the following details:
            ProjectPath      via Get-BuildVariable
            BranchName       via Get-BuildVariable
            CommitMessage    via Get-BuildVariable
            CommitHash       via Get-BuildVariable
            BuildNumber      via Get-BuildVariable
            ProjectName      via Get-ProjectName
            PSModuleManifest via Get-PSModuleManifest
            ModulePath       via Split-Path on PSModuleManifest
            BuildOutput      via BuildOutput parameter

    .PARAMETER Path
        Path to project root. Defaults to the current working path

    .PARAMETER BuildOutput
        Specify a path to use for build output.  Defaults to '$ProjectPath\BuildOutput'

        You may use build variables produced in this same call.  Refer to them as variables, with a literal (escaped) $

        Examples:
            -BuildOutput '$ProjectPath\BuildOutput'
            -BuildOutput 'C:\Build'
            -BuildOutput 'C:\Builds\$ProjectName'

    .PARAMETER GitPath
        Path to git.  Defaults to git (i.e. git is in $ENV:PATH)

    .NOTES
        We assume you are in the project root, for several of the fallback options

    .EXAMPLE
        Get-BuildEnvironment

    .EXAMPLE
        Get-BuildEnvironment -Path C:\sc\PSDepend -BuildOutput 'C:\Builds\$ProjectName'

        # Get BuildEnvironment pointing at C:\sc\PSDepend
        # Assuming ProjectName evaluates to PSDepend, BuildOutput will be set to C:\Builds\PSDepend

    .LINK
        https://github.com/RamblingCookieMonster/BuildHelpers

    .LINK
        Get-BuildVariable

    .LINK
        Set-BuildEnvironment

    .LINK
        Get-ProjectName

    .LINK
        about_BuildHelpers
    #>
    [cmdletbinding()]
    param(
        [validatescript({ Test-Path $_ -PathType Container })]
        $Path = $PWD.Path,

        [string]$BuildOutput = '$ProjectPath\BuildOutput',

        [validatescript({
            if(-not (Get-Command $_ -ErrorAction SilentlyContinue))
            {
                throw "Could not find command at GitPath [$_]"
            }
            $true
        })]
        [string]$GitPath,

        [validateset('object', 'hashtable')]
        [string]$As = 'object'
    )
    $GBVParams = @{Path = $Path}
    if($PSBoundParameters.ContainsKey('GitPath'))
    {
        $GBVParams.add('GitPath', $GitPath)
    }
    ${Build.Vars} = Get-BuildVariable @GBVParams
    ${Build.ProjectName} = Get-ProjectName @GBVParams
    ${Build.ManifestPath} = Get-PSModuleManifest -Path $Path
    if( ${Build.ManifestPath} ) {
        ${Build.ModulePath} = Split-Path -Path ${Build.ManifestPath} -Parent
    }
    else {
        ${Build.ModulePath} = $null
    }
    $BuildHelpersVariables = [ordered]@{
        BuildSystem = ${Build.Vars}.BuildSystem
        ProjectPath = ${Build.Vars}.ProjectPath
        BranchName  = ${Build.Vars}.BranchName
        CommitMessage = ${Build.Vars}.CommitMessage
        CommitHash = ${Build.Vars}.CommitHash
        BuildNumber = ${Build.Vars}.BuildNumber
        ProjectName = ${Build.ProjectName}
        PSModuleManifest = ${Build.ManifestPath}
        ModulePath = ${Build.ModulePath}
    }
    foreach($VarName in $BuildHelpersVariables.keys){
        $BuildOutput = $BuildOutput -replace "\`$$VarName", $BuildHelpersVariables[$VarName]
    }
    $BuildOutput = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($BuildOutput)
    $BuildHelpersVariables.add('BuildOutput', $BuildOutput)
    if($As -eq 'object') {
        return [pscustomobject]$BuildHelpersVariables
    }
    if($As -eq 'hashtable') {
        return $BuildHelpersVariables
    }
}
