$PSVersion = $PSVersionTable.PSVersion.Major
$ModuleName = $ENV:BHProjectName

Import-Module $PSScriptRoot\..\$ModuleName -Force

Describe "$ModuleName PS$PSVersion" {
    Context 'Strict mode' {

        Set-StrictMode -Version latest

        It 'Should load' {
            $Module = Get-Module $ModuleName
            $Module.Name | Should be $ModuleName
            $Commands = $Module.ExportedCommands.Keys
            $Commands -contains 'Get-BuildVariables' | Should Be $True
        }
    }
}

