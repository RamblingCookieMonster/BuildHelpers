function Set-BuildEnvironment {
    <#
    .SYNOPSIS
        Normalize build system and project details into environment variables

    .FUNCTIONALITY
        CI/CD

    .DESCRIPTION
        Normalize build system and project details into environment variables

        Creates the following environment variables:
            $ENV:<VariableNamePrefix>ProjectPath      via Get-BuildVariable
            $ENV:<VariableNamePrefix>BranchName       via Get-BuildVariable
            $ENV:<VariableNamePrefix>CommitMessage    via Get-BuildVariable
            $ENV:<VariableNamePrefix>BuildNumber      via Get-BuildVariable
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

    .PARAMETER CustomVariables
        Specify a hashtable containing one or more additional, custom variables that are to be created when
        setting up the build environment. The hashtable key should be the name of the variable to be created.
        It is not necessary to add the variable prefix--that will be added according to the value of the
        VariableNamePrefix parameter. The value may include variables produced in this same call. Only include
        the variable, not ENV or the prefix. Use a literal $.

        Examples:

            -CustomVariables @{ MyCustomVariable = '$ProjectPath\CustomFolder' }
            -CustomVariables @{ Variable1 = 'foo'; Variable2 = 'bar' }
            -CustomVariables @{
                Variable1 = 'foo'
                Variable2 = 'bar'
            }

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
        Get-BuildVariable

    .LINK
        Get-BuildEnvironment

    .LINK
        Get-ProjectName

    .LINK
        about_BuildHelpers
    #>
    [CmdLetBinding( SupportsShouldProcess = $false )]
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseShouldProcessForStateChangingFunctions', '')]
    param(
        [validatescript({ Test-Path $_ -PathType Container })]
        $Path = $PWD.Path,

        [ValidatePattern('\w*')]
        [String]
        $VariableNamePrefix = 'BH',

        [string]$BuildOutput = '$ProjectPath\BuildOutput',

        [hashtable]
        $CustomVariables = @{},

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
            $prefixedVar = "$VariableNamePrefix$VarName".ToUpperInvariant()

            Write-Verbose "storing [$prefixedVar] with value '$($BuildHelpersVariables[$VarName])'."
            $Output = New-Item -Path Env:\ -Name $prefixedVar -Value $BuildHelpersVariables[$VarName] -Force:$Force
            if ("Azure Pipelines" -eq $BuildHelpersVariables["BuildSystem"]) {
                Set-AzurePipelinesVariable -Name $prefixedVar -Value $BuildHelpersVariables[$VarName]
            }
            if($Passthru)
            {
                $Output
            }
        }
    }
    foreach ($VarName in $CustomVariables.Keys) {
        $PrefixedCustomVarName = "${VariableNamePrefix}${VarName}".ToUpperInvariant()
        $PrefixedCustomVarValue = $CustomVariables[$VarName]

        $CustomVarsNames = $CustomVariables.Keys | Where-Object { $_ -ine $VarName }
        foreach ($CustomVarName in $CustomVarsNames) {
            $PrefixedCustomVarValue = $PrefixedCustomVarValue -replace "\`$$CustomVarName", $CustomVariables[$CustomVarName]
        }

        foreach($BhVarName in $BuildHelpersVariables.keys){
            $PrefixedCustomVarValue = $PrefixedCustomvarValue -replace "\`$$BhVarName", $BuildHelpersVariables[$BhVarName]
        }

        Write-Verbose "Storing [$PrefixedCustomVarName] with value '$PrefixedCustomVarValue'."
        $Output = New-Item -Path Env:\ -Name $PrefixedCustomVarName -Value $PrefixedCustomVarValue -Force:$Force
        if ("Azure Pipelines" -eq $BuildHelpersVariables['BuildSystem']) {
            Set-AzurePipelinesVariable -Name $PrefixedCustomVarName -Value $PrefixedCustomVarValue
        }
        if ($PassThru) {
            $Output
        }
    }
    if($VariableNamePrefix -eq 'BH' -and $BuildHelpersVariables.ModulePath)
    {
        # Handle existing scripts that reference BHPSModulePath
        Write-Verbose "storing [BHPSModulePath] with value '$($BuildHelpersVariables.ModulePath)'"
        $Output = New-Item -Path Env:\ -Name BHPSModulePath -Value $BuildHelpersVariables.ModulePath -Force:$Force
        if ("Azure Pipelines" -eq $BuildHelpersVariables["BuildSystem"]) {
            Set-AzurePipelinesVariable -Name BHPSModulePath -Value $BuildHelpersVariables.ModulePath
        }
        if($Passthru)
        {
            $Output
        }
    }
}
