function Get-FullPath ([string]$Path) {
    # https://github.com/pester/Pester/blob/5796c95e4d6ff5528b8e14865e3f25e40f01bd65/Functions/TestResults.ps1#L13-L27
    $Folder = Split-Path -Path $Path -Parent
    $File = Split-Path -Path $Path -Leaf
    if ( -not ([String]::IsNullOrEmpty($Folder))) {
        $FolderResolved = Resolve-Path -Path $Folder
    }
    else {
        $FolderResolved = Resolve-Path -Path $ExecutionContext.SessionState.Path.CurrentFileSystemLocation
    }
    $Path = Join-Path -Path $FolderResolved.ProviderPath -ChildPath $File

    return $Path
}
