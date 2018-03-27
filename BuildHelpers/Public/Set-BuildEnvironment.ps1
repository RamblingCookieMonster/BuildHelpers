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
            $ENV:BHPSModulePath                       Legacy, via Split-Path on PSModuleManifest

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

    .PARAMETER GitPath
        Path to git.  Defaults to git (i.e. git is in $ENV:PATH)

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
        Get-BuildEnvironment

    .LINK
        Get-ProjectName

    .LINK
        about_BuildHelpers
    #>
    [cmdletbinding()]
    param(
        [validatescript({ Test-Path $_ -PathType Container })]
        $Path = $PWD.Path,

        [ValidatePattern('\w*')]
        [String]
        $VariableNamePrefix = 'BH',

        [string]$BuildOutput = '$ProjectPath\BuildOutput',

        [switch]
        $Force,

        [switch]$Passthru,

        [validatescript({
            if(-not (Get-Command $_ -ErrorAction SilentlyContinue))
            {
                throw "Could not find command at GitPath [$_]"
            }
            $true
        })]
        [string]$GitPath
    )
    $GBEParams = @{
        Path = $Path
        As = 'hashtable'
        BuildOutput = $BuildOutput
    }
    if($PSBoundParameters.ContainsKey('GitPath')) {
        $GBEParams.add('GitPath', $GitPath)
    }
    $BuildHelpersVariables = Get-BuildEnvironment @GBEParams
    foreach ($VarName in $BuildHelpersVariables.Keys) {
        if($null -ne $BuildHelpersVariables[$VarName]) {
            $Output = New-Item -Path Env:\ -Name ('{0}{1}' -f $VariableNamePrefix,$VarName) -Value $BuildHelpersVariables[$VarName] -Force:$Force
            if($Passthru)
            {
                $Output
            }
        }
    }
    if($VariableNamePrefix -eq 'BH' -and $BuildHelpersVariables.ModulePath)
    {
        # Handle existing scripts that reference BHPSModulePath
        $Output = New-Item -Path Env:\ -Name BHPSModulePath -Value $BuildHelpersVariables.ModulePath -Force:$Force
        if($Passthru)
        {
            $Output
        }
    }
}
