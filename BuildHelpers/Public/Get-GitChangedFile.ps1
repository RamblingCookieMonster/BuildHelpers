function Get-GitChangedFile {
    <#
    .SYNOPSIS
        Get a list of files changed in a git commit

    .FUNCTIONALITY
        CI/CD

    .DESCRIPTION
        Get a list of files changed in a git commit

    .PARAMETER Path
        Path to git repo. Defaults to the current working path

    .PARAMETER Commit
        Commit hash

    .PARAMETER Include
        If specified, only return files that are '-like'
        an item in the -Include

    .PARAMETER Exclude
        If specified, exclude any files that are '-like'
        an item in the -Include

    .PARAMETER Resolve
        If specified, run Resolve-Path on the determined git path and file in question

    .EXAMPLE
        Get-GitChangedFile
        # Get files changed in the most recent commit
        # Use the current directory as the git repo path

    .EXAMPLE
        Get-GitChangedFile -Path \\Path\To\Git\Repo
        # Get files changed in the most recent commit
        # Use \\Path\To\Git\Repo as the git repo path

    .Example
        Get-GitChangedFile -Commit 3d6b25ebbc6bbf961a4c1045548bc9ff90879bc6

        # Get files changed in commit 3d6b25ebbc6bbf961a4c1045548bc9ff90879bc6,
        # Use the current directory as the git repo path

    .LINK
        https://github.com/RamblingCookieMonster/BuildHelpers

    .LINK
        about_BuildHelpers
    #>
    [cmdletbinding()]
    param(
        [validateScript({ Test-Path $_ -PathType Container })]
        $Path = $PWD.Path,

        $Commit,

        [string[]]$Include,

        [string[]]$Exclude,

        [switch]$Resolve
    )
    $Path = (Resolve-Path $Path).Path
    $GitPathRaw = Invoke-Git rev-parse --show-toplevel -Path $Path
    Write-Verbose "Found git root [$GitPathRaw]"
    $GitPath = Resolve-Path $GitPathRaw
    if(Test-Path $GitPath)
    {
        Write-Verbose "Using [$GitPath] as repo root"
    }
    else
    {
        throw "Could not find root of git repo under [$Path].  Tried [$GitPath]"
    }

    if(-not $PSBoundParameters.ContainsKey('Commit'))
    {
        $Commit = Invoke-Git rev-parse HEAD -Path $GitPath
    }
    if(-not $Commit)
    {
        return
    }

    [string[]]$Files = Invoke-Git "diff-tree --no-commit-id --name-only -r $Commit" -Path $GitPath
    if($Files.Count -gt 0)
    {
        $Params = @{Collection = $Files}
        Write-Verbose "Found [$($Files.Count)] files with raw values:`n$($Files | Foreach {"'$_'"} | Out-String)"
        if($Include)
        {
            $Files = Invoke-LikeFilter @params -FilterArray $Include
        }
        if($Exclude)
        {
            $Files = Invoke-LikeFilter @params -FilterArray $Exclude -Not
        }
        foreach($item in $Files)
        {
            if($Resolve)
            {
                ( Resolve-Path (Join-Path $GitPath $Item) ).Path
            }
            else
            {
                Join-Path $GitPath $Item
            }
        }
    }
    else
    {
        Write-Warning "Something went wrong, no files returned:`nIs [$Path], with repo root [$GitPath] a valid git path?"
    }
}