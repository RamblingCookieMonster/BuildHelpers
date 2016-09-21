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

        [string[]]$Exclude
    )

    Push-Location

    Set-Location $Path
    $GitPath = Resolve-Path (git rev-parse --show-toplevel)
    if(Test-Path $GitPath)
    {
        Write-Verbose "Using [$GitPath] as repo root"
        Set-Location $GitPath
    }
    else
    {
        throw "Could not find root of git repo under [$Path].  Tried [$GitPath]"
    }

    Try
    {
        if(-not $PSBoundParameters.ContainsKey('Commit'))
        {
            $Commit = git rev-parse HEAD
        }
        [string[]]$Files = git diff-tree --no-commit-id --name-only -r $Commit
        if($Files.Count -gt 0)
        {
            $Params = @{Collection = $Files}
            Write-Verbose "Found [$($Files.Count)] files"
            if($Include)
            {
                $Files = Invoke-LikeFilter @params -FilterArray $Include
            }
            if($Exclude)
            {
                $Files = Invoke-LikeFilter @params -FilterArray $Exclude -Not
            }
            (Resolve-Path $Files).Path
        }
        else
        {
            Write-Warning "Something went wrong, no files returned:`nIs [$Path], with repo root [$GitPath] a valid git path?"
        }
    }
    Finally
    {
        Pop-Location
    }
}