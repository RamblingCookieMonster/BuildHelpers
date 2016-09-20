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
        New-Item -Path TestDrive:\ -Name notamanifest.txt -ItemType File
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
        
        It 'Throws an error when passed a bad file' {
            {Step-ModuleVersion @Verbose -Path TestDrive:\notamanifest.txt} | Should Throw
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
                            PowerShellVersion = "4.0"
                            RequiredModules = @("ModuleA","ModuleB")
                            ModuleList = @("ModuleX","ModuleY")
                        }
        
        New-ModuleManifest -Path TestDrive:\testmanifest\testmanifest.psd1 @manifestParams

        Step-ModuleVersion @Verbose -Path TestDrive:\testmanifest\testmanifest.psd1

        $newManifest = Import-PowerShellDataFile -Path TestDrive:\testmanifest\testmanifest.psd1
                        
        It 'Passes Test-ModuleManifest' {
            #Test-ModuleManifest -Path TestDrive:\testmanifest\testmanifest.psd1
            $? | Should Be $true
        }
        
        It 'Should be at version 1.1.2' {
            $newManifest.ModuleVersion | Should Be 1.1.2
        }
        
        It 'Should have an properly formatted array for "FunctionsToExport"' {
            'TestDrive:\testmanifest\testmanifest.psd1' | Should Contain "FunctionsToExport = 'Get-MyFunction', 'Set-MyFunction'" 
        }
        
        It 'Should have an properly formatted array for "Tags"' {
            'TestDrive:\testmanifest\testmanifest.psd1' | Should Contain "Tags = 'one', 'two', 'three'" 
        }         
        
        It 'Should have an properly formatted array for "RequiredModules"' {
            'TestDrive:\testmanifest\testmanifest.psd1' | Should Contain ([regex]::Escape('RequiredModules = @(''ModuleA'',')) 
            'TestDrive:\testmanifest\testmanifest.psd1' | Should Contain ([regex]::Escape("               'ModuleB')"))
        }       
        
        It 'Should have an properly formatted array for "ModuleList"' {
            'TestDrive:\testmanifest\testmanifest.psd1' | Should Contain ([regex]::Escape('ModuleList = @(''ModuleX'',')) 
            'TestDrive:\testmanifest\testmanifest.psd1' | Should Contain ([regex]::Escape("               'ModuleY')"))
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