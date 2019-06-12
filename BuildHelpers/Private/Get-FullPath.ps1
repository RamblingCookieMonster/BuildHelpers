function Get-FullPath {
    <#
    .SYNOPSIS
        Get the full qualified path of a file or folder
    .DESCRIPTION
        Get the full qualified path of a file or folder

        Native cmdlets do not resolve relative paths and paths containing a
        PSDrive properly.
        This function is able to resolve both of these into full qualified
        paths.
    .EXAMPLE
        PS C:\project\MyProject> Get-FullPath ./.gitignore

        Returns the full path of .gitignore:
        C:\project\MyProject\.gitignore
    .EXAMPLE
        PS Projects:\MyProject>  Get-FullPath "Projects:\MyProject\.gitignore"

        Returns the full path of .gitignore:
        C:\project\MyProject\.gitignore
    .LINK
        https://github.com/pester/Pester/blob/5796c95e4d6ff5528b8e14865e3f25e40f01bd65/Functions/TestResults.ps1#L13-L27
    #>
    [CmdletBinding()]
    param(
        # A Path to a file or folder
        #
        # Can be a full path or relative to the current working directory
        [Parameter( Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName )]
        [Alias("FullName", "PSPath")]
        [String[]]$Path
    )

    process {
        foreach ($_path in $Path) {
            $folder = Split-Path -Path $_path -Parent
            $file = Split-Path -Path $_path -Leaf

            if ( -not ([String]::IsNullOrEmpty($folder))) {
                $FolderResolved = Resolve-Path -Path $folder
            }
            else {
                $folderResolved = Resolve-Path -Path $ExecutionContext.SessionState.Path.CurrentFileSystemLocation
            }

            Join-Path -Path $folderResolved.ProviderPath -ChildPath $file
        }
    }
}
