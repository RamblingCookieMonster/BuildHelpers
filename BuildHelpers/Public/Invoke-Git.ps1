Function Invoke-Git {
    <#
    .SYNOPSIS
        Wrapper to invoke git and return streams

    .FUNCTIONALITY
        CI/CD

    .DESCRIPTION
        Wrapper to invoke git and return streams

    .PARAMETER Arguments
        If specified, call git with these arguments.

        This takes a positional argument and accepts all value afterwards for a more natural 'git-esque' use.

    .PARAMETER Path
        Working directory to launch git within.  Defaults to current location

    .PARAMETER GitPath
        Path to git.  Defaults to git (i.e. git is in $ENV:PATH)

    .EXAMPLE
        Invoke-Git rev-parse HEAD

        # Get the current commit hash for HEAD

    .EXAMPLE
        Invoke-Git rev-parse HEAD -path C:\sc\PSStackExchange

        # Get the current commit hash for HEAD for the repo located at C:\sc\PSStackExchange

    .LINK
        https://github.com/RamblingCookieMonster/BuildHelpers

    .LINK
        about_BuildHelpers
    #>
    [cmdletbinding()]
    param(
        [parameter(Position = 0,
                    ValueFromRemainingArguments = $true)]
        $Arguments,

        $Path = $PWD.Path,

        [validatescript({
            if(-not (Get-Command $_ -ErrorAction SilentlyContinue))
            {
                throw "Could not find command at GitPath [$_]"
            }
            $true
        })]
        [string]$GitPath = 'git'
    )

    $Path = (Resolve-Path $Path).Path
    if(!$PSBoundParameters.ContainsKey('GitPath')) {
        $GitPath = (Get-Command $GitPath -ErrorAction Stop)[0].Path
    }

    try
    {
        Push-Location $Path
        $result = & $GitPath $($Arguments -split " ") 2>&1
    }
    finally
    {
        Pop-Location
    }

    $output = [pscustomobject]@{
        Command = "$GitPath $Arguments"
        Output = ""
        Error = ""
    }
    if ($result.writeErrorStream)
    {
        $output.Error = $result.Exception.Message
    }
    else
    {
        $output.Output = $result
    }
    $output
}
