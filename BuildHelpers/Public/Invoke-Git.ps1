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

        $NoWindow = $true,
        $RedirectStandardError = $true,
        $RedirectStandardOutput = $true,
        $UseShellExecute = $false,
        $Path = $PWD.Path,
        $Quiet,
        $Split = "`n",
        $Raw,
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
    # http://stackoverflow.com/questions/8761888/powershell-capturing-standard-out-and-error-with-start-process
    $pinfo = [System.Diagnostics.ProcessStartInfo]@{
        FileName               = $GitPath
        Arguments              = ''
        WorkingDirectory       = $Path
        UseShellExecute        = $UseShellExecute
        CreateNoWindow         = $NoWindow
        RedirectStandardOutput = $RedirectStandardOutput
        RedirectStandardError  = $RedirectStandardError
    }
    $Command = $GitPath
    if (![string]::IsNullOrWhiteSpace($Arguments)) {
        $pinfo.Arguments = $Arguments
        $Command = '{0} {1}' -f $Command, $Arguments
    }
    $p = [System.Diagnostics.Process]::Start($pInfo)

    $stringBuilder = [text.stringbuilder]::new()
    while ($null -ne ($line = $p.StandardOutput.ReadLine())) {
        $null = $stringBuilder.AppendLine($line.Trim())
    }
    $stdout = if ($split) { $stringBuilder.ToString() -split "`n" } else { $stringBuilder.ToString() }

    $null = $stringBuilder.Clear()
    while ($null -ne ($line = $p.StandardError.ReadLine())) {
        $null = $stringBuilder.AppendLine($line.Trim())
    }
    $stderr = if ($split) { $stringBuilder.ToString() -split "`n" } else { $stringBuilder.ToString() }

    $p.WaitForExit()
    if ($Quiet) {
        return
    }

    if ($Raw) {
        [pscustomobject]@{
            Command = $Command
            Output  = $stdout
            Error   = $stderr
        }
    } else {
        if ($stdout) {
            $stdout
        }
        if ($stderr) {
            foreach ($errLine in $stderr) {
                Write-Error $errLine
            }
        }
    }
}
