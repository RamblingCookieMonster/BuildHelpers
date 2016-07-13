A module for saving and loading settings and configuration for PowerShell modules (and scripts).

The Configuration module supports layered configurations with default values, machine values and current user values, and serializes to simple PowerShell metadata format, so your configuration files are just .psd1 files!

The key feature is that you don't have to worry about where to store files, and Modules using the Configuration module for storage will be able to easily store data even when installed in write-protected folders like Program Files.

Installation
============

    Install-Module Configuration

Usage
=====

The Configuration module is meant to be used from other modules (or from scripts) to allow the storage of configuration data (generally, hashtables).

In its simplest form, you add a `Configuration.psd1` file to a module you're authoring, and in there, you put your default settings -- perhaps something as simple as this:

    @{
        DriveName = "data"
    }

Then, in your module, you import those settings _in a function_ when you need them, or expose them to your users like this:

    function Get-FaqConfig {
        Import-Configuration
    }


Perhaps, in a simple case like this one, you might write a wrapper function to get _and set_ that one setting directly:

    function Get-DataDriveName {
        $script:Config = Import-Configuration
        $config.DriveName
    }
    
    function Set-DataDriveName {
        param([Parameter(Mandatory)][String]$Name)
        
        @{ DriveName = $Name} | Export-Config
    }


Of course, you could have imported the configuration, edited that one setting, and then exported the whole config, but you can also just export a few settings, because `Import-Configuration` supports a layered configuration. More on that in a moment, but first, let's talk about how this all works.


How it works
============

The Configuration module works by serializing PowerShell hashtables or custom objects into PowerShell data language in a `Configuration.psd1` file!  When you `Export-Configuration` you can set the `-Scope`, which determines where the Configuration.psd1 are stored:

* **User** exports to `$Env:LocalAppData`
* **Enterprise** exports to `$Env:AppData` (the roaming path)
* **Machine** exports to `$Env:ProgramData` 

Within that folder, the Configuration module root is "WindowsPowerShell," followed by either the company or author, and the module name -- within which  a Configuration.psd1 file is stored.

You can test what that path is by calling the `Get-StoragePath` command. `Get-StoragePath` creates the folder path if it doesn't already exist, so you can also use the folder returned by `Get-StoragePath` to store other files, like cached images, etc.

The actual serialization commands are in the Metadata.psm1 module, with the `Metadata` noun and ConvertFrom, ConvertTo, Import and Export verbs. By default, it can handle all sorts of nested custom PSObjects, hashtables, and arrays, which can contain booleans, strings and numbers, as well as Versions, GUIDs, and DateTime, DateTimeOffset, and even PSCredential objects (which are stored using ConvertTo-SecureString, and must be stored in user scope).

In other words, it handles everything you're likely to need in a configuration file. However, it also has support for adding additional type serializers via the `Add-MetadataConverter` command. If you want to store anything that doesn't work, please raise an issue :wink:.

### Layered Configuration

The major magic of the Configuration module, apart from automatically determining a storage path, is that when you use `Import-Configuration` within a module, it automatically imports _several_ files and updates the configuration object which is returned at the end.

1. First, it imports the default Configuration.psd1 from the module's folder.
2. Then it imports machine-wide settings (from the ProgramData folder)
3. Then it imports your enterprise roaming settings (from AppData\Roaming)
4. Finally it imports your local user settings (from AppData\Local)

Any missing files are just skipped, and each layer of settings updates the settings from the previous layers, so if you don't set a setting in one layer, the setting from the previous layers persists.


#### One little catch

The configuration module uses the caller's scope to determine the name of the module (and Company or Author name) that is asking for configuration.  For this reason you **must** call `Import-Configuration` from within a function in your module (to make sure the callstack shows the module scope).

It _is possible_ to use the commandlets to read and write the config for a module from outside the module (or during module import) in one of two ways:

One way is by piping the module to `Import-Configuration`:

    $Config = Get-Module DataModule | Import-Configuration
    $Config.DriveName = "DataDrive"
    Get-Module DataModule | Export-Configuration $Config

The other way is to specify the module name and company (or author) by hand:

    $Config = Import-Configuration -Name DataModule -Author HuddledMasses.org

The catch with that is that you have to be sure to get the `-Author` or `-CompanyName` the same as what the module exposes, and you have to manually specify the `-DefaultPath` if you want to load the default file.

In either case, the _very important_ side effect is that you must not change the module name nor the author name of your module if you're using this Configuration module, or you will need to manually call `Import-Configuration` with the old information and then `Export` those settings to the new location.

A little history:
=================

The Configuration module is something I first wrote as part of the PoshCode packaging module and have been meaning to pull out for awhile. 

I finally started working on this while I work on writing the Gherkin support for Pester. That support will be merged into Pester after the Pester 3.0 release, but in the meantime, I'm using it to test this module! My [LanguageDecoupling branch of Pester](https://github.com/Jaykul/Pester/tree/LanguageDecoupling) has the test code for ``Invoke-Gherkin`` and this module is serving as the first trial usage.

In any case, this module is mostly code ported from my PoshCode module as I develop the specs (the .feature files) and the Gherkin support to run them! Anything you see here has better than 98% code coverage in the feature and step files, and is executable by the code in my "Gherkin" branch of Pester.

For the tests to work, you need to make sure that the module isn't already loaded, because the tests import it with the file paths mocked. You can unload the module like this:

    Remove-Module Configuration -ErrorAction SilentlyContinue

And verify the tests with this command, assuming you get my Pester fork:

    Invoke-Gherkin -CodeCoverage *.psm1
