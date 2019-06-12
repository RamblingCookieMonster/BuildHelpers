function Get-GitChangedFile {
    <#
    .SYNOPSIS
        Get a list of files changed in a git commit

    .FUNCTIONALITY
        CI/CD

    .DESCRIPTION
        Get a list of files changed in a git commit
        Uses git diff to find changed files
        By default it will get you the files changed in the current commit,
        or a specific commit can be specified.
        You can also use LeftRevision, RightRevision, and RangeNotation parameters
        to specify your own range, useful when determing what has changed in a merge
        or what would change in a hypothetical merge

    .PARAMETER Path
        Path to git repo. Defaults to the current working path

    .PARAMETER Commit
        Commit hash

    .PARAMETER Include
        If specified, only return files that are '-like'
        an item in the -Include
        If both Include and Exclude are specified, files that match the Include and don't match the Exclude will be returned
        In other words, the Include is applied first, and then any Exclude patterns are removed

    .PARAMETER Exclude
        If specified, exclude any files that are '-like'
        an item in the -Exclude
        If both Include and Exclude are specified, files that match the Include and don't match the Exclude will be returned
        In other words, the Include is applied first, and then any Exclude patterns are removed

    .PARAMETER Resolve
        If specified, run Resolve-Path on the determined git path and file in question

    .PARAMETER DiffFilter
        If specified, use this string as a value to the --diff-filter parameter of git diff.
        Some examples:
        "A" would only return files added
        "M" would only return files modified
        "AM" would only return files that were added or modified
        "d" would exclude files that have been deleted
        "dm" would exclude files that have been deleted or modified
        More information on the --diff-filter available at https://git-scm.com/docs/git-diff#Documentation/git-diff.txt---diff-filterACDMRTUXB82308203

    .PARAMETER LeftRevision
        If specified, use this value as part of a range comparision along with RangeNotation and optionally RightRevision

    .PARAMETER RangeNotation
        If specified, use this value as part of a range comparision along with LeftRevision and/or RightRevision
        If not specified, but either or both of LeftRevision and RightRevision are specified, it will default to triple dot notation.
        Defaults to triple dot (...) notation, which will only show changes in one "direction"
        Double dot (..) notation can also be specified, which shows all changes between the two revisions

    .PARAMETER RightRevision
        If specified, use this value as part of a range comparision along with RangeNotation and optionally LeftRevision

    .PARAMETER RawRevisionString
        If specified, this value will be passed directly to git diff instead of constructing a revsion based on other parameters.
        This gives you more flexibility in how you specify your revisions

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

    .EXAMPLE
        Get-GitChangedFile -LeftRevision "origin/master"
        # Shows the files that are "ahead" of orgin/master
        # These are the same files that you would see if you used the
        # Compare button to compare your current branch to master
        # When one revision is not specified it is assumed to be
        # HEAD (the currently checked out revision)
        # This command is functionally equivalent to:
        # Get-GitChangedFile -LeftRevision "origin/master" -RightRevision "Head"
        # Get-Get-GitChangedFile -LeftRevision "origin/master" -RangeNotation "..." -RightRevision "Head"
        # Get-Get-GitChangedFile -LeftRevision "origin/master" -RangeNotation "..."

    .Example
        Get-GitChangedFile -RawRevisionString "origin/master..."

        # Functionally equivalent to passing "origin/master" as a parameter to LeftRevision as described above

    .LINK
        https://github.com/RamblingCookieMonster/BuildHelpers

    .LINK
        https://git-scm.com/docs/git-diff

    .LINK
        about_BuildHelpers
    #>
    [cmdletbinding(DefaultParameterSetName="All")]
    param(
        [validateScript({ Test-Path $_ -PathType Container })]
        [Parameter(ParameterSetName="All")]
        [Parameter(ParameterSetName="Commit")]
        [Parameter(ParameterSetName="Range")]
        [Parameter(ParameterSetName="RangeLeft")]
        [Parameter(ParameterSetName="RangeRight")]
        [Parameter(ParameterSetName="RawRevision")]
        $Path = $PWD.Path,

        [Parameter(Mandatory,ParameterSetName="Commit")]
        [string]$Commit,

        [Parameter(Mandatory,ParameterSetName="Range")]
        [Parameter(Mandatory,ParameterSetName="RangeLeft")]
        [string]$LeftRevision,

        [Parameter(ParameterSetName="Range")]
        [Parameter(ParameterSetName="RangeLeft")]
        [Parameter(ParameterSetName="RangeRight")]
        [ValidateSet("..","...")]
        [string]$RangeNotation="...",

        [Parameter(Mandatory,ParameterSetName="Range")]
        [Parameter(Mandatory,ParameterSetName="RangeRight")]
        [string]$RightRevision,

        [ValidatePattern("^[ACDMRTUXBacdmrtuxb*]+$")]
        [string]$DiffFilter,

        [Parameter(ParameterSetName="RawRevision")]
        [string]$RawRevisionString,

        [string[]]$Include,


        [string[]]$Exclude,

        [switch]$Resolve
    )
    $Path = (Resolve-Path $Path).Path
    try
    {
        $GitPathRaw = Invoke-Git rev-parse --show-toplevel -Path $Path -ErrorAction Stop
    }
    catch
    {
        if ($_ -like "fatal: not a git repository*" )
        {
            throw "Could not find root of git repo under [$Path], are you sure [$Path] is in a git repository?"
        }
        else
        {
            throw $_
        }
    }
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
    if($PSCmdlet.ParameterSetName -eq 'Commit')
    {
        $revisionString = $Commit + "^!"
    }
    elseif ($PSCmdlet.ParameterSetName -like 'Range*')
    {
        $revisionString = $LeftRevision + $RangeNotation + $RightRevision
        Write-Verbose "revision string: $revisionString"
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'RawRevision')
    {
        $revisionString = $RawRevisionString
    }
    else 
    {
        $revisionString = "HEAD^!"
    }
    if ($PSBoundParameters.ContainsKey('DiffFilter'))
    {
        $revisionString += " --diff-filter=$DiffFilter"
    }
    if(-not $revisionString)
    {
        return
    }

    [string[]]$Files = Invoke-Git "diff --name-only $revisionString" -Path $GitPath
    if ($Files) {
        Write-Verbose "Found [$($Files.Count)] files with raw values:`n$($Files | Foreach-Object {"'$_'"} | Out-String)"
        if($Include)
        {
            $Files = Invoke-LikeFilter -Collection $Files -FilterArray $Include -FilterReplace '\','/'
        }
        if($Exclude)
        {
            $Files = Invoke-LikeFilter -Collection $Files -FilterArray $Exclude -FilterReplace '\','/' -Not
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
        Write-Warning "No files found that match the given criteria"
    }
}
