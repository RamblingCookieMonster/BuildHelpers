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

        .PARAMETER RedirectStandardError
            Whether to capture standard error.  Defaults to $true

        .PARAMETER RedirectStandardOutput
            Whether to capture standard output.  Defaults to $true

        .PARAMETER UseShellExecute
            See System.Diagnostics.ProcessStartInfo.  Defaults to $false

        .PARAMETER Raw
            If specified, return an object with the command, output, and error properties.

            Without Raw or Quiet, we return output if there's output, and we write an error if there are errors

        .PARAMETER Split
            If specified, split output and error on this.  Defaults to `n

        .PARAMETER Quiet
            If specified, do not return output

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

            [switch]$Quiet,

            [switch]$Raw,

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

        $result = & $GitPath $Arguments 2>&1

        if(-not $Quiet) {
            $output = [pscustomobject]@{
                Command = "$GitPath $Arguments"
                Output = ""
                Error = ""
            }
            if ($result.writeErrorStream)
            {
                $output.Error = $result.Exception.Message -join "`n"
            }
            else
            {
                $output.Output = $result -join "`n"
            }

            if($Raw)
            {
                $output
            }
            else
            {
                if ($result.writeErrorStream)
                {
                    $output.Error
                }
                else
                {
                    $output.Output
                }
            }
        }
    }
