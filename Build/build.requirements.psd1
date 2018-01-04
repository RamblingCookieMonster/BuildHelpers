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
        Version = '0.2.2'
    }
    'BuildHelpers' = @{
        DependencyType = 'PSGalleryNuget'
        Version = '0.0.57'
    }
    'Pester' = @{
        DependencyType = 'PSGalleryNuget'
        Version = '3.4.6'
    }
}