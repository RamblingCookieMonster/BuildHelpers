# Allows you to override the Scope storage paths (e.g. for testing)
param(
    $Converters     = @{},
    $EnterpriseData = $Env:AppData,
    $UserData       = $Env:LocalAppData,
    $MachineData    = $Env:ProgramData
)

$EnterpriseData = Join-Path $EnterpriseData WindowsPowerShell
$UserData       = Join-Path $UserData   WindowsPowerShell
$MachineData    = Join-Path $MachineData WindowsPowerShell

$ConfigurationRoot = Get-Variable PSScriptRoot* -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq "PSScriptRoot" } | ForEach-Object { $_.Value }
if(!$ConfigurationRoot) {
    $ConfigurationRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

Import-Module "${ConfigurationRoot}\Metadata.psm1" -Force -Args @($Converters)

function Get-StoragePath {
    #.Synopsis
    #   Gets an application storage path outside the module storage folder
    #.Description
    #   Gets an AppData (or roaming profile) or ProgramData path for settings storage
    #
    #   As a general rule, there are three scopes which result in three different root folders
    #       User:       $Env:LocalAppData
    #       Machine:    $Env:ProgramData
    #       Enterprise: $Env:AppData (which is the "roaming" folder of AppData)
    #
    #   WARNINGs:
    #       1.  This command is only meant to be used in modules, to find a place where they can serialize data for storage. It can be used in scripts, but doing so is more risky.
    #       2.  Since there are multiple module paths, it's possible for more than one module to exist with the same name, so you should exercise care
    #
    #   If it doesn't already exist, the folder is created before the path is returned, so you can always trust this folder to exist.
    #   The folder that is returned survives module uninstall/reinstall/upgrade, and this is the lowest level API for the Configuration module, expecting the module author to export data there using other Import/Export cmdlets.
    #.Example
    #   $CacheFile = Join-Path (Get-StoragePath) Data.clixml
    #   $Data | Export-CliXML -Path $CacheFile
    #
    #   This example shows how to use Get-StoragePath with Export-CliXML to cache some data from inside a module.
    #
    [CmdletBinding(DefaultParameterSetName = '__ModuleInfo')]
    param(
        # The scope to save at, defaults to Enterprise (which returns a path in "RoamingData")
        [Security.PolicyLevelType]$Scope = "Enterprise",

        # A callstack. You should not ever pass this.
        # It is used to calculate the defaults for all the other parameters.
        [Parameter(ParameterSetName = "__CallStack")]
        [System.Management.Automation.CallStackFrame[]]$CallStack = $(Get-PSCallStack),

        # The Module you're importing configuration for
        [Parameter(ParameterSetName = "__ModuleInfo", ValueFromPipeline = $true)]
        [System.Management.Automation.PSModuleInfo]$Module = $(
            $mi = ($CallStack)[0].InvocationInfo.MyCommand.Module
            if($mi -and $mi.ExportedCommands.Count -eq 0) {
                if($mi2 = Get-Module $mi.ModuleBase -ListAvailable | Where-Object Name -eq $mi.Name | Where-Object ExportedCommands | Select-Object -First 1) {
                   return $mi2
                }
            }
            return $mi
        ),

        # An optional module qualifier (by default, this is blank)
        [Parameter(ParameterSetName = "ManualOverride", Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias("Author")]
        [String]$CompanyName = $(
            if($Module){
                $Name = $Module.CompanyName -replace "[$([Regex]::Escape(-join[IO.Path]::GetInvalidFileNameChars()))]","_"
                if($Name -eq "Unknown" -or -not $Name) {
                    $Name = $Module.Author
                    if($Name -eq "Unknown" -or -not $Name) {
                        $Name = "AnonymousModules"
                    }
                }
                $Name
            } else {
                "AnonymousScripts"
            }
        ),

        # The name of the module or script
        # Will be used in the returned storage path
        [Parameter(ParameterSetName = "ManualOverride", Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [String]$Name = $(if($Module) { $Module.Name }),

        # The full path (including file name) of a default Configuration.psd1 file
        # By default, this is expected to be in the same folder as your module manifest, or adjacent to your script file
        [Parameter(ParameterSetName = "ManualOverride", ValueFromPipelineByPropertyName=$true)]
        [Alias("ModuleBase")]
        [String]$DefaultPath = $(if($Module) { Join-Path $Module.ModuleBase Configuration.psd1 }),


        # The version for saved settings -- if set, will be used in the returned path
        # NOTE: this is *NOT* calculated from the CallStack
        [Version]$Version
    )
    begin {
        $PathRoot = $(switch ($Scope) {
            "Enterprise" { $EnterpriseData }
            "User"       { $UserData }
            "Machine"    { $MachineData }
            # This should be "Process" scope, but what does that mean?
            # "AppDomain"  { $MachineData }
            default { $EnterpriseData }
        })
    }

    process {
        if(!$Name) {
            throw "Could not determine the storage name, Get-StoragePath should only be called from inside a script or module."
        }
        $CompanyName = $CompanyName -replace "[$([Regex]::Escape(-join[IO.Path]::GetInvalidFileNameChars()))]","_"

        Write-Verbose "Storage Root: $PathRoot"
        $PathRoot = Join-Path $PathRoot $Type

        if($CompanyName -and $CompanyName -ne "Unknown") {
            $PathRoot = Join-Path $PathRoot $CompanyName
        }

        $PathRoot = Join-Path $PathRoot $Name

        if($Version) {
            $PathRoot = Join-Path $PathRoot $Version
        }

        Write-Verbose "Storage Path: $PathRoot"

        # Note: avoid using Convert-Path because drives aliases like "TestData:" get converted to a C:\ file system location
        $null = mkdir $PathRoot -Force
        (Resolve-Path $PathRoot).Path
    }
}

function Export-Configuration {
    <#
        .Synopsis
            Exports a configuration object to a specified path.
        .Description
            Exports the configuration object to a file, by default, in the Roaming AppData location
        
            NOTE: this exports the FULL configuration to this file, which will override both defaults and local machine configuration when Import-Configuration is used.
        .Example
            @{UserName = $Env:UserName; LastUpdate = [DateTimeOffset]::Now } | Export-Configuration
        
            This example shows how to use Export-Configuration in your module to cache some data.
        
        .Example
            Get-Module Configuration | Export-Configuration @{UserName = $Env:UserName; LastUpdate = [DateTimeOffset]::Now }
        
            This example shows how to use Export-Configuration to export data for use in a specific module.
    #>
    [CmdletBinding(DefaultParameterSetName='__ModuleInfo',SupportsShouldProcess)]
    param(
        # Specifies the objects to export as metadata structures.
        # Enter a variable that contains the objects or type a command or expression that gets the objects.
        # You can also pipe objects to Export-Metadata.
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0)]
        $InputObject,

        # A callstack. You should not ever pass this.
        # It is used to calculate the defaults for all the other parameters.
        [Parameter(ParameterSetName = "__CallStack")]
        [System.Management.Automation.CallStackFrame[]]$CallStack = $(Get-PSCallStack),

        # The Module you're importing configuration for
        [Parameter(ParameterSetName = "__ModuleInfo", ValueFromPipeline = $true)]
        [System.Management.Automation.PSModuleInfo]$Module = $(
            $mi = ($CallStack)[0].InvocationInfo.MyCommand.Module
            if($mi -and $mi.ExportedCommands.Count -eq 0) {
                if($mi2 = Get-Module $mi.ModuleBase -ListAvailable | Where-Object Name -eq $mi.Name | Where-Object ExportedCommands | Select-Object -First 1) {
                   return $mi2
                }
            }
            return $mi
        ),


        # An optional module qualifier (by default, this is blank)
        [Parameter(ParameterSetName = "ManualOverride", Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias("Author")]
        [String]$CompanyName = $(
            if($Module){
                $Name = $Module.CompanyName -replace "[$([Regex]::Escape(-join[IO.Path]::GetInvalidFileNameChars()))]","_"
                if($Name -eq "Unknown" -or -not $Name) {
                    $Name = $Module.Author
                    if($Name -eq "Unknown" -or -not $Name) {
                        $Name = "AnonymousModules"
                    }
                }
                $Name
            } else {
                "AnonymousScripts"
            }
        ),

        # The name of the module or script
        # Will be used in the returned storage path
        [Parameter(ParameterSetName = "ManualOverride", Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [String]$Name = $(if($Module) { $Module.Name }),

        # The full path (including file name) of a default Configuration.psd1 file
        # By default, this is expected to be in the same folder as your module manifest, or adjacent to your script file
        [Parameter(ParameterSetName = "ManualOverride", ValueFromPipelineByPropertyName=$true)]
        [Alias("ModuleBase")]
        [String]$DefaultPath = $(if($Module) { Join-Path $Module.ModuleBase Configuration.psd1 }),

        # The scope to save at, defaults to Enterprise (which returns a path in "RoamingData")
        [Parameter(ParameterSetName = "ManualOverride")]
        [Security.PolicyLevelType]$Scope = "Enterprise",

        # The version for saved settings -- if set, will be used in the returned path
        # NOTE: this is *NOT* calculated from the CallStack
        [Version]$Version
    )
    process {
        if(!$Name) {
            throw "Could not determine the storage name, Get-StoragePath should only be called from inside a script or module."
        }

        $Parameters = @{
            CompanyName = $CompanyName
            Name = $Name
        }
        if($Version) {
            $Parameters.Version = $Version
        }

        $MachinePath = Get-StoragePath @Parameters -Scope $Scope

        $ConfigurationPath = Join-Path $MachinePath "Configuration.psd1"

        $InputObject | Export-Metadata $ConfigurationPath
    }
}

function Import-Configuration {
    #.Synopsis
    #   Import the full, layered configuration for the module.
    #.Description
    #   Imports the DefaultPath Configuration file, and then imports the Machine, Roaming (enterprise), and local config files, if they exist.
    #   Each configuration file is layered on top of the one before (so only needs to set values which are different)
    #.Example
    #   $Configuration = Import-Configuration
    #
    #   This example shows how to use Import-Configuration in your module to load the cached data
    #
    #.Example
    #   $Configuration = Get-Module Configuration | Import-Configuration
    #
    #   This example shows how to use Import-Configuration in your module to load data cached for another module
    #
    [CmdletBinding(DefaultParameterSetName = '__CallStack')]
    param(
        # A callstack. You should not ever pass this.
        # It is used to calculate the defaults for all the other parameters.
        [Parameter(ParameterSetName = "__CallStack")]
        [System.Management.Automation.CallStackFrame[]]$CallStack = $(Get-PSCallStack),

        # The Module you're importing configuration for
        [Parameter(ParameterSetName = "__ModuleInfo", ValueFromPipeline = $true)]
        [System.Management.Automation.PSModuleInfo]$Module = $(
            $mi = ($CallStack)[0].InvocationInfo.MyCommand.Module
            if($mi -and $mi.ExportedCommands.Count -eq 0) {
                if($mi2 = Get-Module $mi.ModuleBase -ListAvailable | Where-Object Name -eq $mi.Name | Where-Object ExportedCommands | Select-Object -First 1) {
                   return $mi2
                }
            }
            return $mi
        ),

        # An optional module qualifier (by default, this is blank)
        [Parameter(ParameterSetName = "ManualOverride", Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias("Author")]
        [String]$CompanyName = $(
            if($Module){
                $Name = $Module.CompanyName -replace "[$([Regex]::Escape(-join[IO.Path]::GetInvalidFileNameChars()))]","_"
                if($Name -eq "Unknown" -or -not $Name) {
                    $Name = $Module.Author
                    if($Name -eq "Unknown" -or -not $Name) {
                        $Name = "AnonymousModules"
                    }
                }
                $Name
            } else {
                "AnonymousScripts"
            }
        ),

        # The name of the module or script
        # Will be used in the returned storage path
        [Parameter(ParameterSetName = "ManualOverride", Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [String]$Name = $(if($Module) { $Module.Name }),

        # The full path (including file name) of a default Configuration.psd1 file
        # By default, this is expected to be in the same folder as your module manifest, or adjacent to your script file
        [Parameter(ParameterSetName = "ManualOverride", ValueFromPipelineByPropertyName=$true)]
        [Alias("ModuleBase")]
        [String]$DefaultPath = $(if($Module) { Join-Path $Module.ModuleBase Configuration.psd1 }),

        # The version for saved settings -- if set, will be used in the returned path
        # NOTE: this is *never* calculated, if you use version numbers, you must manage them on your own
        [Version]$Version,

        # If set (and PowerShell version 4 or later) preserve the file order of configuration
        # This results in the output being an OrderedDictionary instead of Hashtable
        [Switch]$Ordered
    )
    begin {
        Write-Verbose "Module Name $Name"
    }
    process {
        if(!$Name) {
            throw "Could not determine the configuration name. When you are not calling Import-Configuration from a module, you must specify the -Author and -Name parameter"
        }        

        if(Test-Path $DefaultPath -Type Container) {
            $DefaultPath = Join-Path $DefaultPath Configuration.psd1
        }

        Write-Verbose "PSBoundParameters $($PSBoundParameters | Out-String)"
        $Configuration = if(Test-Path $DefaultPath) {
                             Import-Metadata $DefaultPath -ErrorAction Ignore -Ordered:$Ordered
                         } else { @{} }
        Write-Verbose "Module ($DefaultPath)`n$($Configuration | Out-String)"

        $Parameters = @{
            CompanyName = $CompanyName
            Name = $Name
        }
        if($Version) {
            $Parameters.Version = $Version
        }

        $MachinePath = Get-StoragePath @Parameters -Scope Machine
        $MachinePath = Join-Path $MachinePath Configuration.psd1
        $Machine = if(Test-Path $MachinePath) {
                    Import-Metadata $MachinePath -ErrorAction Ignore -Ordered:$Ordered
                } else { @{} }
        Write-Verbose "Machine ($MachinePath)`n$($Machine | Out-String)"


        $EnterprisePath = Get-StoragePath @Parameters -Scope Enterprise
        $EnterprisePath = Join-Path $EnterprisePath Configuration.psd1
        $Enterprise = if(Test-Path $EnterprisePath) {
                    Import-Metadata $EnterprisePath -ErrorAction Ignore -Ordered:$Ordered
                } else { @{} }
        Write-Verbose "Enterprise ($EnterprisePath)`n$($Enterprise | Out-String)"

        $LocalUserPath = Get-StoragePath @Parameters -Scope User
        $LocalUserPath = Join-Path $LocalUserPath Configuration.psd1
        $LocalUser = if(Test-Path $LocalUserPath) {
                    Import-Metadata $LocalUserPath -ErrorAction Ignore -Ordered:$Ordered
                } else { @{} }
        Write-Verbose "LocalUser ($LocalUserPath)`n$($LocalUser | Out-String)"

        $Configuration | Update-Object $Machine |
                         Update-Object $Enterprise |
                         Update-Object $LocalUser
    }
}
# SIG # Begin signature block
# MIIXxAYJKoZIhvcNAQcCoIIXtTCCF7ECAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU+EnruXvfkbzbaYKyiaeMo3zx
# RXGgghL3MIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
# AQUFADCBizELMAkGA1UEBhMCWkExFTATBgNVBAgTDFdlc3Rlcm4gQ2FwZTEUMBIG
# A1UEBxMLRHVyYmFudmlsbGUxDzANBgNVBAoTBlRoYXd0ZTEdMBsGA1UECxMUVGhh
# d3RlIENlcnRpZmljYXRpb24xHzAdBgNVBAMTFlRoYXd0ZSBUaW1lc3RhbXBpbmcg
# Q0EwHhcNMTIxMjIxMDAwMDAwWhcNMjAxMjMwMjM1OTU5WjBeMQswCQYDVQQGEwJV
# UzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFu
# dGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALGss0lUS5ccEgrYJXmRIlcqb9y4JsRDc2vCvy5Q
# WvsUwnaOQwElQ7Sh4kX06Ld7w3TMIte0lAAC903tv7S3RCRrzV9FO9FEzkMScxeC
# i2m0K8uZHqxyGyZNcR+xMd37UWECU6aq9UksBXhFpS+JzueZ5/6M4lc/PcaS3Er4
# ezPkeQr78HWIQZz/xQNRmarXbJ+TaYdlKYOFwmAUxMjJOxTawIHwHw103pIiq8r3
# +3R8J+b3Sht/p8OeLa6K6qbmqicWfWH3mHERvOJQoUvlXfrlDqcsn6plINPYlujI
# fKVOSET/GeJEB5IL12iEgF1qeGRFzWBGflTBE3zFefHJwXECAwEAAaOB+jCB9zAd
# BgNVHQ4EFgQUX5r1blzMzHSa1N197z/b7EyALt0wMgYIKwYBBQUHAQEEJjAkMCIG
# CCsGAQUFBzABhhZodHRwOi8vb2NzcC50aGF3dGUuY29tMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwPwYDVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NybC50aGF3dGUuY29tL1Ro
# YXd0ZVRpbWVzdGFtcGluZ0NBLmNybDATBgNVHSUEDDAKBggrBgEFBQcDCDAOBgNV
# HQ8BAf8EBAMCAQYwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFRpbWVTdGFtcC0y
# MDQ4LTEwDQYJKoZIhvcNAQEFBQADgYEAAwmbj3nvf1kwqu9otfrjCR27T4IGXTdf
# plKfFo3qHJIJRG71betYfDDo+WmNI3MLEm9Hqa45EfgqsZuwGsOO61mWAK3ODE2y
# 0DGmCFwqevzieh1XTKhlGOl5QGIllm7HxzdqgyEIjkHq3dlXPx13SYcqFgZepjhq
# IhKjURmDfrYwggSjMIIDi6ADAgECAhAOz/Q4yP6/NW4E2GqYGxpQMA0GCSqGSIb3
# DQEBBQUAMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMB4XDTEyMTAxODAwMDAwMFoXDTIwMTIyOTIzNTk1OVowYjELMAkGA1UE
# BhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTQwMgYDVQQDEytT
# eW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIFNpZ25lciAtIEc0MIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAomMLOUS4uyOnREm7Dv+h8GEKU5Ow
# mNutLA9KxW7/hjxTVQ8VzgQ/K/2plpbZvmF5C1vJTIZ25eBDSyKV7sIrQ8Gf2Gi0
# jkBP7oU4uRHFI/JkWPAVMm9OV6GuiKQC1yoezUvh3WPVF4kyW7BemVqonShQDhfu
# ltthO0VRHc8SVguSR/yrrvZmPUescHLnkudfzRC5xINklBm9JYDh6NIipdC6Anqh
# d5NbZcPuF3S8QYYq3AhMjJKMkS2ed0QfaNaodHfbDlsyi1aLM73ZY8hJnTrFxeoz
# C9Lxoxv0i77Zs1eLO94Ep3oisiSuLsdwxb5OgyYI+wu9qU+ZCOEQKHKqzQIDAQAB
# o4IBVzCCAVMwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwcwYIKwYBBQUHAQEEZzBlMCoGCCsGAQUFBzABhh5odHRw
# Oi8vdHMtb2NzcC53cy5zeW1hbnRlYy5jb20wNwYIKwYBBQUHMAKGK2h0dHA6Ly90
# cy1haWEud3Muc3ltYW50ZWMuY29tL3Rzcy1jYS1nMi5jZXIwPAYDVR0fBDUwMzAx
# oC+gLYYraHR0cDovL3RzLWNybC53cy5zeW1hbnRlYy5jb20vdHNzLWNhLWcyLmNy
# bDAoBgNVHREEITAfpB0wGzEZMBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMjAdBgNV
# HQ4EFgQURsZpow5KFB7VTNpSYxc/Xja8DeYwHwYDVR0jBBgwFoAUX5r1blzMzHSa
# 1N197z/b7EyALt0wDQYJKoZIhvcNAQEFBQADggEBAHg7tJEqAEzwj2IwN3ijhCcH
# bxiy3iXcoNSUA6qGTiWfmkADHN3O43nLIWgG2rYytG2/9CwmYzPkSWRtDebDZw73
# BaQ1bHyJFsbpst+y6d0gxnEPzZV03LZc3r03H0N45ni1zSgEIKOq8UvEiCmRDoDR
# EfzdXHZuT14ORUZBbg2w6jiasTraCXEQ/Bx5tIB7rGn0/Zy2DBYr8X9bCT2bW+IW
# yhOBbQAuOA2oKY8s4bL0WqkBrxWcLC9JG9siu8P+eJRRw4axgohd8D20UaF5Mysu
# e7ncIAkTcetqGVvP6KUwVyyJST+5z3/Jvz4iaGNTmr1pdKzFHTx/kuDDvBzYBHUw
# ggUmMIIEDqADAgECAhACXbrxBhFj1/jVxh2rtd9BMA0GCSqGSIb3DQEBCwUAMHIx
# CzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3
# dy5kaWdpY2VydC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJ
# RCBDb2RlIFNpZ25pbmcgQ0EwHhcNMTUwNTA0MDAwMDAwWhcNMTYwNTExMTIwMDAw
# WjBtMQswCQYDVQQGEwJVUzERMA8GA1UECBMITmV3IFlvcmsxFzAVBgNVBAcTDldl
# c3QgSGVucmlldHRhMRgwFgYDVQQKEw9Kb2VsIEguIEJlbm5ldHQxGDAWBgNVBAMT
# D0pvZWwgSC4gQmVubmV0dDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
# AJfRKhfiDjMovUELYgagznWf+HFcDENk118Y/K6UkQDwKmVyVOvDyaVefjSmZZcV
# NZqqYpm9d/Iajf2dauyC3pg3oay8KfXAADLHgbmbvYDc5zGuUNsTzMUOKlp9h13c
# qsg898JwpRpI659xCQgJjZ6V83QJh+wnHvjA9ojjA4xkbwhGp4Eit6B/uGthEA11
# IHcFcXeNI3fIkbwWiAw7ZoFtSLm688NFhxwm+JH3Xwj0HxuezsmU0Yc/po31CoST
# nGPVN8wppHYZ0GfPwuNK4TwaI0FEXxwdwB+mEduxa5e4zB8DyUZByFW338XkGfc1
# qcJJ+WTyNKFN7saevhwp02cCAwEAAaOCAbswggG3MB8GA1UdIwQYMBaAFFrEuXsq
# CqOl6nEDwGD5LfZldQ5YMB0GA1UdDgQWBBQV0aryV1RTeVOG+wlr2Z2bOVFAbTAO
# BgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwdwYDVR0fBHAwbjA1
# oDOgMYYvaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC1jcy1n
# MS5jcmwwNaAzoDGGL2h0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9zaGEyLWFzc3Vy
# ZWQtY3MtZzEuY3JsMEIGA1UdIAQ7MDkwNwYJYIZIAYb9bAMBMCowKAYIKwYBBQUH
# AgEWHGh0dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwgYQGCCsGAQUFBwEBBHgw
# djAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tME4GCCsGAQUF
# BzAChkJodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRTSEEyQXNz
# dXJlZElEQ29kZVNpZ25pbmdDQS5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0B
# AQsFAAOCAQEAIi5p+6eRu6bMOSwJt9HSBkGbaPZlqKkMd4e6AyKIqCRabyjLISwd
# i32p8AT7r2oOubFy+R1LmbBMaPXORLLO9N88qxmJfwFSd+ZzfALevANdbGNp9+6A
# khe3PiR0+eL8ZM5gPJv26OvpYaRebJTfU++T1sS5dYaPAztMNsDzY3krc92O27AS
# WjTjWeILSryqRHXyj8KQbYyWpnG2gWRibjXi5ofL+BHyJQRET5pZbERvl2l9Bo4Z
# st8CM9EQDrdG2vhELNiA6jwenxNPOa6tPkgf8cH8qpGRBVr9yuTMSHS1p9Rc+ybx
# FSKiZkOw8iCR6ZQIeKkSVdwFf8V+HHPrETCCBTAwggQYoAMCAQICEAQJGBtf1btm
# dVNDtW+VUAgwDQYJKoZIhvcNAQELBQAwZTELMAkGA1UEBhMCVVMxFTATBgNVBAoT
# DERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEkMCIGA1UE
# AxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4XDTEzMTAyMjEyMDAwMFoX
# DTI4MTAyMjEyMDAwMFowcjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0
# IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNl
# cnQgU0hBMiBBc3N1cmVkIElEIENvZGUgU2lnbmluZyBDQTCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBAPjTsxx/DhGvZ3cH0wsxSRnP0PtFmbE620T1f+Wo
# ndsy13Hqdp0FLreP+pJDwKX5idQ3Gde2qvCchqXYJawOeSg6funRZ9PG+yknx9N7
# I5TkkSOWkHeC+aGEI2YSVDNQdLEoJrskacLCUvIUZ4qJRdQtoaPpiCwgla4cSocI
# 3wz14k1gGL6qxLKucDFmM3E+rHCiq85/6XzLkqHlOzEcz+ryCuRXu0q16XTmK/5s
# y350OTYNkO/ktU6kqepqCquE86xnTrXE94zRICUj6whkPlKWwfIPEvTFjg/Bougs
# UfdzvL2FsWKDc0GCB+Q4i2pzINAPZHM8np+mM6n9Gd8lk9ECAwEAAaOCAc0wggHJ
# MBIGA1UdEwEB/wQIMAYBAf8CAQAwDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoG
# CCsGAQUFBwMDMHkGCCsGAQUFBwEBBG0wazAkBggrBgEFBQcwAYYYaHR0cDovL29j
# c3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRwOi8vY2FjZXJ0cy5kaWdp
# Y2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3J0MIGBBgNVHR8EejB4
# MDqgOKA2hjRodHRwOi8vY3JsNC5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVk
# SURSb290Q0EuY3JsMDqgOKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGln
# aUNlcnRBc3N1cmVkSURSb290Q0EuY3JsME8GA1UdIARIMEYwOAYKYIZIAYb9bAAC
# BDAqMCgGCCsGAQUFBwIBFhxodHRwczovL3d3dy5kaWdpY2VydC5jb20vQ1BTMAoG
# CGCGSAGG/WwDMB0GA1UdDgQWBBRaxLl7KgqjpepxA8Bg+S32ZXUOWDAfBgNVHSME
# GDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzANBgkqhkiG9w0BAQsFAAOCAQEAPuwN
# WiSz8yLRFcgsfCUpdqgdXRwtOhrE7zBh134LYP3DPQ/Er4v97yrfIFU3sOH20ZJ1
# D1G0bqWOWuJeJIFOEKTuP3GOYw4TS63XX0R58zYUBor3nEZOXP+QsRsHDpEV+7qv
# tVHCjSSuJMbHJyqhKSgaOnEoAjwukaPAJRHinBRHoXpoaK+bp1wgXNlxsQyPu6j4
# xRJon89Ay0BEpRPw5mQMJQhCMrI2iiQC/i9yfhzXSUWW6Fkd6fp0ZGuy62ZD2rOw
# jNXpDd32ASDOmTFjPQgaGLOBm0/GkxAG/AeB+ova+YJJ92JuoVP6EpQYhS6Skepo
# bEQysmah5xikmmRR7zGCBDcwggQzAgEBMIGGMHIxCzAJBgNVBAYTAlVTMRUwEwYD
# VQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAv
# BgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcgQ0EC
# EAJduvEGEWPX+NXGHau130EwCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcCAQwxCjAI
# oAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIB
# CzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFClF/dcon4cieh9oF6XU
# lIAzjU5YMA0GCSqGSIb3DQEBAQUABIIBADIUB0CCRuGt9gdQCThQvGl03IIVylpd
# bnRemNrjwgl1ejy6YiGM8mS92I5SXQzLZ8JMpRLryVsN+d3ZrQQfpv2l6Ojs8Y+d
# +GDeeP75k1mwInPXjhTNMUYiiuZEJYukGscRaDtVWkT4izsKd5Zx3u4FD5Flxz0o
# DIL2h8YJTdAhC9z8cAek8zgGeVweZBVK8wmdiWtDytpSEA8A//NGnmT/I3UAHwrk
# qwyQaAH+tQMio//nUh0eJFtWFTuovVwph0N4dwUK8QwxH8Xk8K+dWTlsx5qcYayH
# 9gQO87cX+RSYzE7OElzGkLh3sn6noT1cUk12GWiqs9GI7RJ6W9+KyNOhggILMIIC
# BwYJKoZIhvcNAQkGMYIB+DCCAfQCAQEwcjBeMQswCQYDVQQGEwJVUzEdMBsGA1UE
# ChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFudGVjIFRpbWUg
# U3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMgIQDs/0OMj+vzVuBNhqmBsaUDAJBgUr
# DgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUx
# DxcNMTYwNTExMDU0OTE0WjAjBgkqhkiG9w0BCQQxFgQUWF19VV6gPwU0iB7/eTZB
# +FjG3xgwDQYJKoZIhvcNAQEBBQAEggEAD8KscxX094NtJZPZ35f1l9PtdgWnhmv6
# Z3WeOo71wXOH/0g5b9gCTptteg+LpfjOxDTspXsiyQ7+XIlKa4cYw+fhA0PiRGnX
# p2R/JXzkrcJWMw2RGtKDYdE/PdtNfiBO/uvf4a4VwiBSBO9Rjw5/ohNraJSgMR11
# 26eaqveecrIkhsrpswzFYRtkKuK1wZe8GzvIVi/SP2j7L0iA7rfiLK9/4Sl3QMuN
# hyObkjXFsjpzz6mTU6F0AoMgJM2KmpHHC8oxDjJqFAB3IzW4vFCnLmnlwzZX5QP6
# GWY5yabKQwi3PKfW/Az43QTtRwpuZ3ebmTi9HAaXw1MI8q9WZCrHsQ==
# SIG # End signature block
