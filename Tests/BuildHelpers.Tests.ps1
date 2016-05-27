$PSVersion = $PSVersionTable.PSVersion.Major
$ModuleName = $ENV:BHProjectName

# Verbose output for non-master builds on appveyor
# Handy for troubleshooting.
# Splat @Verbose against commands as needed (here or in pester tests)
    $Verbose = @{}
    if($ENV:BHBranchName -notlike "master")
    {
        $Verbose.add("Verbose",$True)
    }

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

Describe "Get-ProjectName PS$PSVersion" {
    Context 'Strict mode' {

        Set-StrictMode -Version latest

        It 'Should pick by same name nested folder' {
            $ProjectName = Get-ProjectName $PSScriptRoot\TestData\ProjectX
            $ProjectName | Should Be 'ProjectX'
        }
        It 'Should pick by PSD1 in folder' {
            $ProjectName = Get-ProjectName $PSScriptRoot\TestData\ProjectPSD
            $ProjectName | Should Be 'ProjectPSD'
        }
        It 'Should pick by PSD1 in subfolder' {
            $ProjectName = Get-ProjectName $PSScriptRoot\TestData\ProjectSubPSD
            $ProjectName | Should Be 'ProjectSubPSD'
        }
        It 'Should pick by PSD1 in subfolder with different name' {
            $ProjectName = Get-ProjectName $PSScriptRoot\TestData\ProjectWTF
            $ProjectName | Should Be 'ProjectEvil'
        }
    }
}

