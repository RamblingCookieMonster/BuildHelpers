function Set-BuildEnvironment {
    <#
    .SYNOPSIS
        Normalize build system and project details into environment variables

    .FUNCTIONALITY
        CI/CD

    .DESCRIPTION
        Normalize build system and project details into environment variables

        Creates the following environment variables:
            $ENV:<VariableNamePrefix>ProjectPath      via Get-BuildVariables
            $ENV:<VariableNamePrefix>BranchName       via Get-BuildVariables
            $ENV:<VariableNamePrefix>CommitMessage    via Get-BuildVariables
            $ENV:<VariableNamePrefix>BuildNumber      via Get-BuildVariables
            $ENV:<VariableNamePrefix>ProjectName      via Get-ProjectName
            $ENV:<VariableNamePrefix>PSModuleManifest via Get-PSModuleManifest
            $ENV:<VariableNamePrefix>ModulePath       via Split-Path on PSModuleManifest
            $ENV:<VariableNamePrefix>BuildOutput      via BuildOutput parameter

        If you don't specify a prefix or use BH, we create BHPSModulePath (This will be removed July 1st)

    .PARAMETER Path
        Path to project root. Defaults to the current working path

    .PARAMETER VariableNamePrefix
        Allow to set a custom Prefix to the Environment variable created. The default is BH such as $Env:BHProjectPath

    .PARAMETER BuildOutput
        Specify a path to use for build output.  Defaults to '$ProjectPath\BuildOutput'

        You may use build variables produced in this same call.  Only include the variable, not ENV or the prefix.  Use a literal $.

        Examples:
            -BuildOutput '$ProjectPath\BuildOutput'
            -BuildOutput 'C:\Build'
            -BuildOutput 'C:\Builds\$ProjectName'

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

    .EXAMPLE
        Set-BuildEnvironment -Path C:\sc\PSDepend -BuildOutput 'C:\Builds\$ProjectName'

        # Set BuildEnvironment pointing at C:\sc\PSDepend
        # Assuming ProjectName evaluates to PSDepend, BuildOutput variable will be set to C:\Builds\PSDepend

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

        [string]$BuildOutput = '$ProjectPath\BuildOutput',

        [switch]
        $Force,

        [switch]$Passthru
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
        ModulePath = ${Build.ModulePath}
    }
    foreach($VarName in $BuildHelpersVariables.keys){
        $BuildOutput = $BuildOutput -replace "\`$$VarName", $BuildHelpersVariables[$VarName]
    }
    $BuildOutput = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($BuildOutput)
    $BuildHelpersVariables.add('BuildOutput', $BuildOutput)
    foreach ($VarName in $BuildHelpersVariables.Keys) {
        if($null -ne $BuildHelpersVariables[$VarName]) {
            $Output = New-Item -Path Env:\ -Name ('{0}{1}' -f $VariableNamePrefix,$VarName) -Value $BuildHelpersVariables[$VarName] -Force:$Force
            if($Passthru)
            {
                $Output
            }
        }
    }
    if($VariableNamePrefix -eq 'BH' -and ${Build.ModulePath})
    {
        Write-Warning ( "`$ENV:BHPSModulePath is deprecated and will be removed July 1st, 2017`n`n" +
                        "ACTION REQUIRED: Please replace `$ENV:BHPSModulePath with `$ENV:BHModulePath wherever you use it" )
        $Output = New-Item -Path Env:\ -Name BHPSModulePath -Value ${Build.ModulePath} -Force:$Force
        if($Passthru)
        {
            $Output
        }
    }
}