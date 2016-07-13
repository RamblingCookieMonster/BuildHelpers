@{

# Script module or binary module file associated with this manifest.
ModuleToProcess = '.\Configuration.psm1'

# Version number of this module.
ModuleVersion = '0.8'

# ID used to uniquely identify this module
GUID = 'e56e5bec-4d97-4dfd-b138-abbaa14464a6'

# Author of this module
Author = @('Joel Bennett')

# Company or vendor of this module
CompanyName = 'HuddledMasses.org'

# HelpInfo URI of this module
# HelpInfoURI = ''

# Copyright statement for this module
Copyright = 'Copyright (c) 2014-2016 by Joel Bennett, all rights reserved.'

# Description of the functionality provided by this module
Description = 'A module for storing and reading configuration values, with full PS Data serialization, automatic configuration for modules and scripts, etc.'

# We explicitly name the functions we want to be visible, but we export everything with '*'
FunctionsToExport = 'Import-Configuration','Export-Configuration','Get-StoragePath','Add-MetadataConverter',
                    'ConvertFrom-Metadata','ConvertTo-Metadata','Export-Metadata','Import-Metadata',
                    'Update-Manifest','Get-ManifestValue','*'

# Cmdlets to export from this module
CmdletsToExport = '*'

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module
AliasesToExport = '*'

# List of all files packaged with this module
FileList = @('Configuration.psd1','Configuration.psm1','Metadata.psm1','README.md','LICENSE')

PrivateData = @{
    # PSData is module packaging and gallery metadata embedded in PrivateData
    # It's for the PoshCode and PowerShellGet modules
    # We had to do this because it's the only place we're allowed to extend the manifest
    # https://connect.microsoft.com/PowerShell/feedback/details/421837
    PSData = @{
        # Keyword tags to help users find this module via navigations and search.
        Tags = @('Development','Configuration','Settings','Storage')

        # The web address of this module's project or support homepage.
        ProjectUri = "https://github.com/PoshCode/Configuration"

        # The web address of this module's license. Points to a page that's embeddable and linkable.
        LicenseUri = "http://opensource.org/licenses/MIT"

        # Release notes for this particular version of the module
        ReleaseNotes = 'Added a new converter for ConsoleColor and fixed some ScriptAnalyzer warnings.'

        # Indicates this is a pre-release/testing version of the module.
        IsPrerelease = 'True'
    }
}

}
