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

Import-Module $PSScriptRoot\..\$ModuleName -Force

Describe "$ModuleName PS$PSVersion" {
    Context 'Strict mode' {

        Set-StrictMode -Version latest

        It 'Should load' {
            $Module = @( Get-Module $ModuleName )
            $Module.Name -contains $ModuleName | Should be $True
            $Commands = $Module.ExportedCommands.Keys
            $Commands -contains 'Get-BuildVariables' | Should Be $True
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
        It 'Should pick by PSD1 in folder' {
            $ProjectName = Get-ProjectName @Verbose $PSScriptRoot\TestData\ProjectPSD
            $ProjectName | Should Be 'ProjectPSD'
        }
        It 'Should pick by PSD1 in subfolder' {
            $ProjectName = Get-ProjectName @Verbose $PSScriptRoot\TestData\ProjectSubPSD
            $ProjectName | Should Be 'ProjectSubPSD'
        }
        It 'Should pick by PSD1 in subfolder with different name' {
            $ProjectName = Get-ProjectName @Verbose $PSScriptRoot\TestData\ProjectWTF
            $ProjectName | Should Be 'ProjectEvil'
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

        # TODO: Fix this.  Merge commits will fail this test, makes this test somewhat pointless?
        # It 'Should find at least one file from the last commit in this repo' {
        #     $Output = Get-GitChangedFile
        #     @($Output).count | Should BeGreaterThan 0
        #     Test-Path @($Output)[0] | Should Be $true
        # }
              
        It 'Should find files changed in a specified commit in this repo' {
            $Output = Get-GitChangedFile -Commit 01b3931e6ed5d3d16cbcae25fcf98d185c1375b7 -ErrorAction SilentlyContinue -Include README*
            @($Output).count | Should Be 1
            @($Output)[0] | Should BeLike "*BuildHelpers\README.md"
        }
    }

    Context 'Invalid repository' {
        It "Should fail if we don't find a valid git repo" {
            {Get-GitChangedFile C:\ -ErrorAction Stop} | Should Throw
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

Describe 'Get-ModuleFunctions' {
    Context 'dummymodule' {
        It 'Should return the functions output by a module' {
            $Functions = Get-ModuleFunctions -Name $PSScriptRoot\TestData\dummymodule
            $Functions.Count | Should be 3
            'a', 'b', 'c' | Foreach {
                $Functions -contains $_ | Should Be $True
            }
        }
    }
}

Describe 'Set-ModuleFunctions' {
    Context 'dummymodule' {
        $dummydir = ( mkdir $PSScriptRoot\TestData\dummymodule ).FullName
        Copy-item $PSScriptRoot\TestData\dummymodule.psd1 $dummydir -Confirm:$False
        Copy-item $PSScriptRoot\TestData\dummymodule.psm1 $dummydir -Confirm:$False
        It 'Should update the module manifest with exported functions' {
            Set-ModuleFunctions -Name $dummydir
            $Functions = Get-Metadata $dummydir\dummymodule.psd1 -PropertyName FunctionsToExport
            $Functions.Count | Should be 3
            'a', 'b', 'c' | Foreach {
                $Functions -contains $_ | Should Be $True
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
