@{
    # Some defaults for all dependencies
    PSDependOptions = @{
        Target = '$ENV:USERPROFILE\Documents\WindowsPowerShell\Modules'
        AddToPath = $True
    }

    # Grab some modules without depending on PowerShellGet
    'psake' = @{
        DependencyType = 'PSGalleryNuget'
    }
    'PSDeploy' = @{
        DependencyType = 'PSGalleryNuget'
        Version = '0.1.26'
    }
    'BuildHelpers' = @{
        DependencyType = 'PSGalleryNuget'
        Version = '0.0.34'
    }
    'Pester' = @{
        DependencyType = 'PSGalleryNuget'
        Version = '3.4.6'
    }
}