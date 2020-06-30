$PSVersion = $PSVersionTable.PSVersion.Major
$ModuleName = $ENV:BHProjectName

# Verbose output for non-master builds on appveyor
# Handy for troubleshooting.
# Splat @Verbose against commands as needed (here or in pester tests)
    $Verbose = @{}
    if($ENV:BHBranchName -notlike "master" -or $env:BHCommitMessage -match "!verbose")
    {
        $Verbose.add("Verbose",$True)
    }

Remove-Module $ModuleName
Import-Module $PSScriptRoot\..\$ModuleName -Force

Describe "$ModuleName PS$PSVersion" {
    Context 'Strict mode' {

        Set-StrictMode -Version latest

        It 'Should load' {
            $Module = @( Get-Module $ModuleName )
            $Module.Name -contains $ModuleName | Should be $True
            $Commands = $Module.ExportedCommands.Keys
            $Commands -contains 'Get-BuildVariable' | Should Be $True
        }
    }
}

Describe "Get-ProjectName PS$PSVersion" {
    Context 'Strict mode' {

        Set-StrictMode -Version latest

        It 'Should pick by same name nested folder' {
            $ProjectName = Get-ProjectName @Verbose $PSScriptRoot\TestData\ProjectX
            $ProjectName | Should Be 'ProjectX'
        }
        It 'Should pick by PSD1 in subfolder' {
            $ProjectName = Get-ProjectName @Verbose $PSScriptRoot\TestData\ProjectSubPSD
            $ProjectName | Should Be 'ProjectSubPSD'
        }
        It 'Should pick by PSD1 in subfolder with different name' {
            $ProjectName = Get-ProjectName @Verbose $PSScriptRoot\TestData\ProjectWTF
            $ProjectName | Should Be 'ProjectEvil'
        }
        It 'Should pick by PSD1 in folder' {
            $ProjectName = Get-ProjectName @Verbose $PSScriptRoot\TestData\ProjectPSD
            $ProjectName | Should Be 'ProjectPSD'
        }
        It 'Should pick by PSD1 in folder with a different name' {
            $ProjectName = Get-ProjectName @Verbose $PSScriptRoot\TestData\ProjectExtraIck
            $ProjectName | Should Be 'ProjectIck'
        }
        Context 'Invoking Git' {
            Mock Invoke-Git -ModuleName BuildHelpers {"https://github.com/user/ProjectUseGit.git"}
            Mock Test-Path -ModuleName BuildHelpers {$true} -ParameterFilter {$path -like "*.git"}
            $ProjectName = Get-ProjectName @Verbose $PSScriptRoot\TestData\ProjectUseGit2
            It 'should pick name using Git' {
                $ProjectName | Should Be 'ProjectUseGit'
            }
            It 'should call Invoke-Git' {
                Assert-MockCalled Invoke-Git -ModuleName BuildHelpers -Exactly 1
            }
        }
        It 'should default to the root directory if nthing else' {
            $ProjectName = Get-ProjectName @Verbose $PSScriptRoot\TestData\ProjectDefault
            $ProjectName | Should Be 'ProjectDefault'

        }
        
    }
}

Describe 'Step-Version' {
    Context 'By Param' {
        It 'Should increment the Patch level' {
            $result = Step-Version @Verbose 1.1.1
            $result | Should Be 1.1.2
        }

        It 'Should increment the Minor level and set Patch level to 0' {
            $result = Step-Version @Verbose 1.1.1 Minor
            $result | Should Be 1.2.0
        }

        It 'Should increment the Major level and set the Minor and Patch level to 0' {
            $result = Step-Version @Verbose 1.1.1 Major
            $result | Should Be 2.0.0
        }
    }

    Context 'By Pipeline' {
        It 'Should increment the Patch level' {
            $result = [version]"1.1.1" | Step-Version @Verbose
            $result | Should Be 1.1.2
        }

        It 'Should increment the Minor level and set Patch level to 0' {
            $result = $result = [version]"1.1.1" | Step-Version @Verbose -By Minor
            $result | Should Be 1.2.0
        }

        It 'Should increment the Major level and set the Minor and Patch level to 0' {
            $result = $result = [version]"1.1.1" | Step-Version @Verbose -By Major
            $result | Should Be 2.0.0
        }
    }
}

Describe 'Step-ModuleVersion' {
    Context 'Basic Manifest' {

        New-Item -Path TestDrive:\ -Name testmanifest -ItemType Directory
        New-Item -Path TestDrive:\testmanifest -Name testmanifest.psm1 -ItemType File

        $manifestParams = @{Guid = New-Guid
                            Author = "Name"
                            RootModule = "testmanifest.psm1"
                            ModuleVersion = "1.1.1"
                            Description = "A test module"
                        }

        New-ModuleManifest -Path TestDrive:\testmanifest\testmanifest.psd1 @manifestParams

        Step-ModuleVersion @Verbose -Path TestDrive:\testmanifest\testmanifest.psd1

        $newManifest = Import-PowerShellDataFile @Verbose -Path TestDrive:\testmanifest\testmanifest.psd1

        It 'Passes Test-ModuleManifest' {
            Test-ModuleManifest -Path TestDrive:\testmanifest\testmanifest.psd1
            $? | Should Be $true
        }

        It 'Should be at version 1.1.2' {
            $newManifest.ModuleVersion | Should Be 1.1.2
        }

        It 'The other properties should be the same' {
            $newManifest.Guid | Should Be $manifestParams.Guid
            $newManifest.Author | Should Be $manifestParams.Author
            $newManifest.RootModule | Should Be $manifestParams.RootModule
            $newManifest.Description | Should Be $manifestParams.Description
        }
    }

    Context 'Basic Manifest in PWD' {

        New-Item -Path TestDrive:\ -Name testmanifest -ItemType Directory
        New-Item -Path TestDrive:\ -Name notamanifest.txt -ItemType File
        New-Item -Path TestDrive:\testmanifest -Name testmanifest.psm1 -ItemType File

        $manifestParams = @{Guid = New-Guid
                            Author = "Name"
                            RootModule = "testmanifest.psm1"
                            ModuleVersion = "1.1.1"
                            Description = "A test module"
                        }

        New-ModuleManifest -Path TestDrive:\testmanifest\testmanifest.psd1 @manifestParams
        Push-Location
        Set-Location -Path TestDrive:\testmanifest\

        It 'Should be at version 1.1.2' {
            Step-ModuleVersion @Verbose
            $newManifest = Import-PowerShellDataFile -Path TestDrive:\testmanifest\testmanifest.psd1
            $newManifest.ModuleVersion | Should Be 1.1.2
        }

        Pop-Location
    }

    Context 'Basic Manifest with Minor step' {

        New-Item -Path TestDrive:\ -Name testmanifest -ItemType Directory
        New-Item -Path TestDrive:\testmanifest -Name testmanifest.psm1 -ItemType File

        $manifestParams = @{Guid = New-Guid
                            Author = "Name"
                            RootModule = "testmanifest.psm1"
                            ModuleVersion = "1.1.1"
                            Description = "A test module"
                        }

        New-ModuleManifest -Path TestDrive:\testmanifest\testmanifest.psd1 @manifestParams

        Step-ModuleVersion @Verbose -Path TestDrive:\testmanifest\testmanifest.psd1 -By Minor

        $newManifest = Import-PowerShellDataFile -Path TestDrive:\testmanifest\testmanifest.psd1

        It 'Passes Test-ModuleManifest' {
            Test-ModuleManifest -Path TestDrive:\testmanifest\testmanifest.psd1
            $? | Should Be $true
        }

        It 'Should be at version 1.2.0' {
            $newManifest.ModuleVersion | Should Be 1.2.0
        }

        It 'The other properties should be the same' {
            $newManifest.Guid | Should Be $manifestParams.Guid
            $newManifest.Author | Should Be $manifestParams.Author
            $newManifest.RootModule | Should Be $manifestParams.RootModule
            $newManifest.Description | Should Be $manifestParams.Description
        }
    }
    Context 'Complex Manifest' {

        New-Item -Path TestDrive:\ -Name testmanifest -ItemType Directory
        New-Item -Path TestDrive:\testmanifest -Name testmanifest.psm1 -ItemType File

        $manifestParams = @{Guid = New-Guid
                            Author = "Name"
                            RootModule = "testmanifest.psm1"
                            ModuleVersion = "1.1.1"
                            Description = "A test module"
                            ProjectUri = "http://something.us"
                            Tags = @("one","two","three")
                            FunctionsToExport = @("Get-MyFunction","Set-MyFunction")
                            ProcessorArchitecture = "Amd64"
                            NestedModules = @("Module1","Module2")
                            PowerShellVersion = "4.0"
                            RequiredModules = @("ModuleA","ModuleB")
                            ModuleList = @("ModuleX","ModuleY")
                        }

        New-ModuleManifest -Path TestDrive:\testmanifest\testmanifest.psd1 @manifestParams

        Step-ModuleVersion @Verbose -Path TestDrive:\testmanifest\testmanifest.psd1

        $newManifest = Import-PowerShellDataFile -Path TestDrive:\testmanifest\testmanifest.psd1

        It 'Should be at version 1.1.2' {
            $newManifest.ModuleVersion | Should Be 1.1.2
        }

        It 'Should have an properly formatted array for "FunctionsToExport"' {
            'TestDrive:\testmanifest\testmanifest.psd1' | Should -FileContentMatchExactly "FunctionsToExport = 'Get-MyFunction', 'Set-MyFunction'"
        }

        It 'Should have an properly formatted array for "Tags"' {
            'TestDrive:\testmanifest\testmanifest.psd1' | Should -FileContentMatchExactly "Tags = 'one', 'two', 'three'"
        }

        It 'Should have an properly formatted array for "NestedModules"' {
            'TestDrive:\testmanifest\testmanifest.psd1' | Should -FileContentMatch ([regex]::Escape('NestedModules = @(''Module1'','))
            'TestDrive:\testmanifest\testmanifest.psd1' | Should -FileContentMatch ([regex]::Escape("               'Module2')"))
        }

        It 'Should have an properly formatted array for "RequiredModules"' {
            'TestDrive:\testmanifest\testmanifest.psd1' | Should -FileContentMatch ([regex]::Escape('RequiredModules = @(''ModuleA'','))
            'TestDrive:\testmanifest\testmanifest.psd1' | Should -FileContentMatch ([regex]::Escape("               'ModuleB')"))
        }

        It 'Should have an properly formatted array for "ModuleList"' {
            'TestDrive:\testmanifest\testmanifest.psd1' | Should -FileContentMatch ([regex]::Escape('ModuleList = @(''ModuleX'','))
            'TestDrive:\testmanifest\testmanifest.psd1' | Should -FileContentMatch ([regex]::Escape("               'ModuleY')"))
        }

        It 'The other properties should be the same' {
            $newManifest.Guid | Should Be $manifestParams.Guid
            $newManifest.Author | Should Be $manifestParams.Author
            $newManifest.RootModule | Should Be $manifestParams.RootModule
            $newManifest.Description | Should Be $manifestParams.Description
            $newManifest.PowerShellVersion | Should Be $manifestParams.PowerShellVersion
            $newManifest.ProcessorArchitecture | Should Be $manifestParams.ProcessorArchitecture
            $newManifest.PrivateData["PSData"]["ProjectUri"] | Should Match $manifestParams.ProjectUri
        }
    }
}

Describe 'Get-GitChangedFile' {
    Context 'This repository' {

        It 'Should find at least one file from the last commit in this repo' {
            $Output = Get-GitChangedFile
            @($Output).count | Should BeGreaterThan 0
            Test-Path @($Output)[0] | Should Be $true
        }

        It 'Should find files changed in a specified commit in this repo' {
            $Output = Get-GitChangedFile -Commit 01b3931e6ed5d3d16cbcae25fcf98d185c1375b7 -ErrorAction SilentlyContinue -Include README*
            @($Output).count | Should Be 1
            @($Output)[0] | Should BeLike "*BuildHelpers\README.md"
        }
        It "should properly apply diff filter" {
            $Output = Get-GitChangedFile -Commit 01b3931e6ed5d3d16cbcae25fcf98d185c1375b7 -DiffFilter "M" -ErrorAction SilentlyContinue
            @($Output).count | Should Be 1
            @($Output)[0] | Should BeLike "*BuildHelpers\README.md"
        }
        It "should diff a range with two commits" {
            $output = Get-GitChangedFile -LeftRevision 3e6b1f247b62e583f443be28580c1c1ee8a92db4 -RightRevision c2f4eb0838999a7c867a89a45fbe9de3f38e9ca9
            @($Output).count | Should Be 13
            @($Output)[0] | Should BeLike "*BuildHelpers\BuildHelpers.psd1"
        }
        It "should diff an open range" {
            # This is comparing all the changes from the first commit until now, so the number will change as files are added and deleted, but it should always be at least 1
            $Output = Get-GitChangedFile -LeftRevision 01b3931e6ed5d3d16cbcae25fcf98d185c1375b7
            @($Output).Count | Should -BeGreaterThan 0
            Test-Path @($Output)[0] | Should Be $true
        }
        It "should diff a manually specified revision string" {
            $Output = Get-GitChangedFile -RawRevisionString "3e6b1f247b62e583f443be28580c1c1ee8a92db4...c2f4eb0838999a7c867a89a45fbe9de3f38e9ca9"
            @($Output).count | Should Be 13
            @($Output)[0] | Should BeLike "*BuildHelpers\BuildHelpers.psd1"
        }
        It "applies both include and exclude" {
            $params = @{
                LeftRevision = "3e6b1f247b62e583f443be28580c1c1ee8a92db4"
                RightRevision = "c2f4eb0838999a7c867a89a45fbe9de3f38e9ca9"
                Include = "*.ps1"
                Exclude = "*/Public/*"
            }
            #This will get all *.ps1 files that aren't in the Public Directory
            $Output = get-gitchangedfile @params
            @($Output).Count | Should -Be 4
            @($Output)[0] | Should -BeLike "*Tests\BuildHelpers.Tests.ps1"
        }
        It "Normalizes slashes to the Unix form used with Git" {
            $Output = Get-GitChangedFile -Commit 01b3931e6ed5d3d16cbcae25fcf98d185c1375b7 -Include "Tests\*"
            @($Output).Count | Should -Be 2
            @($Output)[0] | Should -BeLike "*Tests\BuildHelpers.Tests.ps1"
        }
    }

    Context 'Invalid repository' {
        It "Should fail with proper message if we don't find a valid git repo" {
            {Get-GitChangedFile -Path C:\} | Should Throw "Could not find root of git repo under [C:\], are you sure [C:\] is in a git repository?"
        }
    }
}

InModuleScope BuildHelpers {
    Describe "Invoke-LikeFilter" {
        It "Includes strings that match FilterArray" {
            $output = Invoke-LikeFilter -Collection "hello","goodbye" -FilterArray "*llo"
            @($output).Count | Should -be 1
            $output | Should -be "hello"
        }
        It "Excludes strings that match FilterArray" {
            $output = Invoke-LikeFilter -Collection "hello","goodbye" -FilterArray "*llo" -Not
            @($output).Count | Should -be 1
            $output | Should -be "goodbye"
        }
        It "replaces filter strings" {
            $output = Invoke-LikeFilter -Collection "hello1","hello2","goodbye1","goodbye2" -FilterArray "*3" -FilterReplace "3","2"
            @($output).Count | Should -be 2
            $output | Should -Contain "hello2"
            $output | Should -Contain "goodbye2"
        }
    }
}

Describe 'Invoke-Git' {
    Context 'This repository' {
        It 'Should find the root of the BuildHelpers repo' {
            Invoke-Git rev-parse --show-toplevel -Path $PSScriptRoot | Should BeLike "*BuildHelpers"
        }
    }

    Context 'Invalid repository' {
        It "Should fail if we don't find a valid git repo" {
            {Invoke-Git rev-parse --show-toplevel -Path C:\ -ErrorAction Stop} | Should Throw
        }
    }
}

Describe 'Get-ModuleFunction' {
    Context 'dummymodule' {
        It 'Should return the functions output by a module' {
            $Functions = Get-ModuleFunction -Name $PSScriptRoot\TestData\dummymodule
            $Functions.Count | Should be 3
            'a', 'b', 'c' | Foreach {
                $Functions -contains $_ | Should Be $True
            }
        }
        It 'Should return the functions output by a module' {
            $Functions = Get-ModuleFunctions -Name $PSScriptRoot\TestData\dummymodule
            $Functions.Count | Should be 3
            'a', 'b', 'c' | Foreach {
                $Functions -contains $_ | Should Be $True
            }
        }
    }
}

Describe 'Set-ModuleFunction' {
    Context 'dummymodule' {
        $dummydir = ( mkdir $PSScriptRoot\TestData\dummymodule ).FullName
        Copy-item $PSScriptRoot\TestData\dummymodule.psd1 $dummydir -Confirm:$False
        Copy-item $PSScriptRoot\TestData\dummymodule.psm1 $dummydir -Confirm:$False
        It 'Should update the module manifest with exported functions' {
            Set-ModuleFunction -Name $dummydir
            $Functions = Get-Metadata $dummydir\dummymodule.psd1 -PropertyName FunctionsToExport
            $Functions.Count | Should be 3
            'a', 'b', 'c' | Foreach {
                $Functions -contains $_ | Should Be $True
            }
        }
        Remove-Item $dummydir -Force -Confirm:$False -Recurse
    }
}

Describe 'Set-ModuleFormat' {
    Context 'Can set FormatsToProcess with an array of *.ps1xml files' {
        $dummydir = ( mkdir $PSScriptRoot\TestData\dummymodule ).FullName
        Copy-item $PSScriptRoot\TestData\dummymodule.psd1 $dummydir -Confirm:$False
        Copy-item $PSScriptRoot\TestData\dummymodule.psm1 $dummydir -Confirm:$False

        $dummyFormatsDir = Join-Path $dummydir Formats
        New-Item $dummyFormatsDir -ItemType Directory
        New-Item (Join-Path $dummyFormatsDir dummymodule-format1.format.ps1xml) -ItemType File | Out-Null
        New-Item (Join-Path $dummyFormatsDir dummymodule-format2.format.ps1xml) -ItemType File | Out-Null

        It 'Should update the module manifest with formats to process' {
            $FormatsToProcessFiles = Get-ChildItem $dummyFormatsDir\*.ps1xml | Foreach {
                Join-Path .\Formats $_.Name
            }
            Set-ModuleFormat -Name $dummydir -FormatsToProcess $FormatsToProcessFiles
            $FormatsToProcess = Get-Metadata $dummydir\dummymodule.psd1 -PropertyName FormatsToProcess
            $FormatsToProcess.Count | Should be 2
            ".\Formats\dummymodule-format1.format.ps1xml", ".\Formats\dummymodule-format2.format.ps1xml" | Foreach {
                $FormatsToProcess -contains $_ | Should Be $True
            }
        }

        Remove-Item $dummydir -Force -Confirm:$False -Recurse
    }

    Context 'Can set FormatsToProcess using a relative path containing *.ps1xml type files' {
        $dummydir = ( mkdir $PSScriptRoot\TestData\dummymodule ).FullName
        Copy-item $PSScriptRoot\TestData\dummymodule.psd1 $dummydir -Confirm:$False
        Copy-item $PSScriptRoot\TestData\dummymodule.psm1 $dummydir -Confirm:$False

        $dummyFormatsDir = Join-Path $dummydir Formats
        New-Item $dummyFormatsDir -ItemType Directory
        New-Item (Join-Path $dummyFormatsDir dummymodule-format1.format.ps1xml) -ItemType File | Out-Null
        New-Item (Join-Path $dummyFormatsDir dummymodule-format2.format.ps1xml) -ItemType File | Out-Null

        It 'Should update the module manifest with formats to process' {
            Set-ModuleFormat -Name $dummydir -FormatsRelativePath .\Formats
            $FormatsToProcess = Get-Metadata $dummydir\dummymodule.psd1 -PropertyName FormatsToProcess
            $FormatsToProcess.Count | Should be 2
            ".\Formats\dummymodule-format1.format.ps1xml", ".\Formats\dummymodule-format2.format.ps1xml" | Foreach {
                $FormatsToProcess -contains $_ | Should Be $True
            }
        }

        Remove-Item $dummydir -Force -Confirm:$False -Recurse
    }
}

Describe 'Set-ModuleType' {
    Context 'Can set TypesToProcess with an array of *.ps1xml files' {
        $dummydir = ( mkdir $PSScriptRoot\TestData\dummymodule ).FullName
        Copy-item $PSScriptRoot\TestData\dummymodule.psd1 $dummydir -Confirm:$False
        Copy-item $PSScriptRoot\TestData\dummymodule.psm1 $dummydir -Confirm:$False

        $dummyTypesDir = Join-Path $dummydir Types
        New-Item $dummyTypesDir -ItemType Directory
        New-Item (Join-Path $dummyTypesDir dummymodule-types1.types.ps1xml) -ItemType File | Out-Null
        New-Item (Join-Path $dummyTypesDir dummymodule-types2.types.ps1xml) -ItemType File | Out-Null

        It 'Should update the module manifest with types to process' {
            $TypesToProcessFiles = Get-ChildItem $dummyTypesDir\*.ps1xml | Foreach {
                Join-Path .\Types $_.Name
            }
            Set-ModuleType -Name $dummydir -TypesToProcess $TypesToProcessFiles
            $TypesToProcess = Get-Metadata $dummydir\dummymodule.psd1 -PropertyName TypesToProcess
            $TypesToProcess.Count | Should be 2
            ".\Types\dummymodule-types1.types.ps1xml", ".\Types\dummymodule-types1.types.ps1xml" | Foreach {
                $TypesToProcess -contains $_ | Should Be $True
            }
        }

        Remove-Item $dummydir -Force -Confirm:$False -Recurse
    }

    Context 'Can set TypesToProcess using a relative path containing *.ps1xml type files' {
        $dummydir = ( mkdir $PSScriptRoot\TestData\dummymodule ).FullName
        Copy-item $PSScriptRoot\TestData\dummymodule.psd1 $dummydir -Confirm:$False
        Copy-item $PSScriptRoot\TestData\dummymodule.psm1 $dummydir -Confirm:$False

        $dummyTypesDir = Join-Path $dummydir Types
        New-Item $dummyTypesDir -ItemType Directory
        New-Item (Join-Path $dummyTypesDir dummymodule-types1.types.ps1xml) -ItemType File | Out-Null
        New-Item (Join-Path $dummyTypesDir dummymodule-types2.types.ps1xml) -ItemType File | Out-Null

        It 'Should update the module manifest with types to process' {
            Set-ModuleType -Name $dummydir -TypesRelativePath .\Types
            $TypesToProcess = Get-Metadata $dummydir\dummymodule.psd1 -PropertyName TypesToProcess
            $TypesToProcess.Count | Should be 2
            ".\Types\dummymodule-types1.types.ps1xml", ".\Types\dummymodule-types1.types.ps1xml" | Foreach {
                $TypesToProcess -contains $_ | Should Be $True
            }
        }

        Remove-Item $dummydir -Force -Confirm:$False -Recurse
    }
}

Describe 'Set-ShieldsIoBadge' {
    Context 'dummy readme.md' {
        Set-Content -Path TestDrive:\readme.md -Value '![coverage]()'

        Set-ShieldsIoBadge -Subject 'coverage' -Status 75 -AsPercentage -Path TestDrive:\readme.md

        It 'Should update the dummy readme.md with code coverage' {
            Get-Content TestDrive:\readme.md | Should Be '![coverage](https://img.shields.io/badge/coverage-75%25-yellow.svg)'
        }
    }
}

Describe 'Publish-GithubRelease' {
    Mock Get-ProjectName -ModuleName BuildHelpers { "MockedBuildHelpers" }
    Mock Invoke-RestMethod -ModuleName BuildHelpers {
        [PSCustomObject]@{upload_url = "https://upload{?name,label}"}
    }

    Context 'Behavior' {
        It 'Uses $env:BHProjectName as default repository name' {
            Publish-GithubRelease -AccessToken "a" -Owner "a" -TagName "a"

            $assertMockCalledSplat = @{
                CommandName = "Get-ProjectName"
                ModuleName = "BuildHelpers"
                Exactly = $true
                Times = 1
                Scope = "It"
            }
            Assert-MockCalled @assertMockCalledSplat
        }

        It 'Uses the provived RepositoryName' {
            Publish-GithubRelease -AccessToken "a" -Owner "MyUser" -TagName "a" -RepositoryName "MyGithubRepository"

            $assertMockCalledSplat = @{
                CommandName = "Invoke-RestMethod"
                ModuleName = "BuildHelpers"
                ParameterFilter = {
                    $Uri -like "https://api.github.com/repos/MyUser/MyGithubRepository/releases*"
                }
                Exactly = $true
                Times = 1
                Scope = "It"
            }
            Assert-MockCalled @assertMockCalledSplat
        }

        It 'Encodes the PAT to base64' {
            Publish-GithubRelease -AccessToken "abc" -Owner "a" -TagName "a"

            $assertMockCalledSplat = @{
                CommandName = "Invoke-RestMethod"
                ModuleName = "BuildHelpers"
                ParameterFilter = {
                    $Headers.Authorization -eq 'Basic YWJjOngtb2F1dGgtYmFzaWM='
                }
                Exactly = $true
                Times = 1
                Scope = "It"
            }
            Assert-MockCalled @assertMockCalledSplat
        }

        It 'Does not upload files when none are provided' {
            Publish-GithubRelease -AccessToken "abc" -Owner "a" -TagName "a"

            $assertMockCalledSplat = @{
                CommandName = "Invoke-RestMethod"
                ModuleName = "BuildHelpers"
                ParameterFilter = {
                    $Uri -like "https://upload*"
                }
                Exactly = $true
                Times = 0
                Scope = "It"
            }
            Assert-MockCalled @assertMockCalledSplat
        }

        It 'Uploads artifacts' {
            "" > TestDrive:\testfile1.txt
            "" > TestDrive:\testfile2.txt

            Publish-GithubRelease -AccessToken "abc" -Owner "a" -TagName "a" -Artifact "TestDrive:\testfile1.txt", "TestDrive:\testfile2.txt"
            "TestDrive:\testfile1.txt", "TestDrive:\testfile2.txt" | Publish-GithubRelease -AccessToken "abc" -Owner "a" -TagName "a"
            Get-Childitem "TestDrive:\*.txt" | Publish-GithubRelease -AccessToken "abc" -Owner "a" -TagName "a"

            $assertMockCalledSplat = @{
                CommandName = "Invoke-RestMethod"
                ModuleName = "BuildHelpers"
                ParameterFilter = {
                    $Uri -like "https://upload*testfile1.txt"
                }
                Exactly = $true
                Times = 3
                Scope = "It"
            }
            Assert-MockCalled @assertMockCalledSplat

            $assertMockCalledSplat = @{
                CommandName = "Invoke-RestMethod"
                ModuleName = "BuildHelpers"
                ParameterFilter = {
                    $Uri -like "https://upload*testfile2.txt"
                }
                Exactly = $true
                Times = 3
                Scope = "It"
            }
            Assert-MockCalled @assertMockCalledSplat
        }
    }

    Context 'Patameters' {
        It 'Constructs the body of the request correctly' {
            $release = @{
                AccessToken = "00000000000000000000000"
                Owner = "a"
                TagName = "v1.0"
                Name = "Version 1.0"
                ReleaseText = "First version of my cool thing"
                Draft = $true
                PreRelease = $false
            }
            Publish-GithubRelease @release

            $assertMockCalledSplat = @{
                CommandName = "Invoke-RestMethod"
                ModuleName = "BuildHelpers"
                ParameterFilter = {
                    $Body -match "`"tag_name`"\s*:\s*`"v1.0`"" -and
                    $Body -match "`"name`"\s*:\s*`"Version 1.0`"" -and
                    $Body -match "`"body`"\s*:\s*`"First version of my cool thing`"" -and
                    $Body -match "`"draft`"\s*:\s*true"
                }
                Exactly = $true
                Times = 1
                Scope = "It"
            }
            Assert-MockCalled @assertMockCalledSplat
        }

        It 'Does not add optional parameters if not provided' {
            Publish-GithubRelease -AccessToken "a" -Owner "a" -TagName "v0.1" -Name "Beta Version 0.1" -PreRelease

            $assertMockCalledSplat = @{
                CommandName = "Invoke-RestMethod"
                ModuleName = "BuildHelpers"
                ParameterFilter = {
                    $Body -notlike "*target_commitish*" -and
                    $Body -notlike "*body*" -and
                    $Body -notlike "*draft*"
                }
                Exactly = $true
                Times = 1
                Scope = "It"
            }
            Assert-MockCalled @assertMockCalledSplat
        }
    }
}
