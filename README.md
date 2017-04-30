[![Build status](https://ci.appveyor.com/api/projects/status/joxudd6qrahtr802?svg=true)](https://ci.appveyor.com/project/RamblingCookieMonster/buildhelpers)

BuildHelpers
==============

This is a quick and dirty PowerShell module with a variety of helper functions for PowerShell CI/CD scenarios.

Many of our build scripts explicitly reference build-system-specific features.  We might rely on `$ENV:APPVEYOR_REPO_BRANCH` to know which branch we're in, for example.

This certainly works, but we can enable more portable build scripts by bundling up helper functions, normalizing build variables, and avoiding build-system-specific features.

Pull requests and other contributions welcome!

## Instructions

```powershell
# One time setup
    # Download the repository
    # Unblock the zip
    # Extract the BuildHelpers folder to a module path (e.g. $env:USERPROFILE\Documents\WindowsPowerShell\Modules\)

    #Simple alternative, if you have PowerShell 5, or the PowerShellGet module:
        Install-Module BuildHelpers

# Import the module.
    Import-Module BuildHelpers

# Get commands in the module
    Get-Command -Module BuildHelpers

# Get help
    Get-Help Get-BuildVariables -Full
    Get-Help about_BuildHelpers
```

## Examples

### Get Normalized Build Variables

```powershell
Get-BuildVariables

# We assume you're in the project root. If not, specify a path:
Get-BuildVariables -Path C:\MyProjectRoot
```

### Get Project Name

We occasionally need to reference the project or module name:

```powershell
Get-ProjectName
```

This checks the following expected file system organizations, in order:

(1) *File structure*:

* ProjectX (Repo root)
  * ProjectX (Project here)

*Output*: ProjectX

(2) *File structure*:

* ProjectX (Repo root)
  * DifferentName (Project here. tsk tsk)
    * DifferentName.psd1

*Output*: DifferentName

(3) *File structure*:

* ProjectX (Repo root)
  * ProjectX.psd1 (Please don't use this organization...)

*Output*: ProjectX

(5) *File structure*:

* ProjectWhatever (Repo root)
  * src (or source)
    * ProjectX.psd1

*Output*: ProjectX

(6) *File structure*:

* ProjectX
  * NoHelpfulIndicatorsOfProjectName.md

*Output*: ProjectX

### Create Normalized Environment Variables

This runs a few commands from BuildHelpers module, and populates ENV:BH... variables

```powershell
# Read the current environment, populate env vars
Set-BuildEnvironment

# Read back the env vars
Get-Item ENV:BH*
```

Here's an example, having run Set-BuildEnvironment in an AppVeyor project:

[![AppVeyor Example](/Media/AppVeyor.png)](https://ci.appveyor.com/project/RamblingCookieMonster/psdepend/build/1.0.91)

### Update your FunctionsToExport

During the module authoring process, updating FunctionsToExport can be tedious, so many folks leave this set to '*', missing out on module auto-loading and other benefits.

To get the best of both worlds, use FunctionsToExport='*', and use Set-ModuleFunctions in your build before deployment:

```powershell
# Set your build environment (we use this to get psd1 path)
Set-BuildEnvironment

# Check current FunctionsToExport:
Select-String -Path .\PSSlack\PSSlack.psd1 -Pattern FunctionsToExport

    # PSSlack\PSSlack.psd1:61:FunctionsToExport = '*'

# Update the psd1 with Set-ModuleFunctions:
Set-ModuleFunctions

# Check FunctionsToExport again:
Select-String -Path .\PSSlack\PSSlack.psd1 -Pattern FunctionsToExport

    # PSSlack\PSSlack.psd1:61:FunctionsToExport = @('Find-SlackMessage','Get-PSSlackConfig','Get-SlackChannel','Get-SlackHistory','Get-SlackUser','New-SlackField','New-SlackMessage','New-SlackMessageAttachment','Send-SlackApi','Send-SlackFile','Send-SlackMessage','Set-PSSlackConfig')
```

### Update your ModuleVersion

Typical examples take an existing PSD1 file and bump the module version from that.  Not so helpful if you don't commit that version to Git: The next time you bump the version, you're bumping the original version.

```powershell
# Get the latest version for a project
$Version = Get-NextPSGalleryVersion -Name $env:BHProjectName

# Update the module metadata with the new version - thanks to Joel Bennett for this function!
Update-Metadata -Path $env:BHPSModuleManifest -PropertyName ModuleVersion -Value $Version
```

## Notes

Thanks to Joel Bennett for the ConvertTo-Metadata function that we use in Set-ModuleFunctions!