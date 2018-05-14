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
        [parameter(
            Position = 0,
            ValueFromRemainingArguments = $true
        )]
        [String]$Arguments,

        [Bool]$NoWindow = $true,
        [Bool]$RedirectStandardError = $true,
        [Bool]$RedirectStandardOutput = $true,
        [Bool]$UseShellExecute = $false,
        [String]$Path = $PWD.Path,
        [Switch]$Quiet,
        [String]$Split = "`n",
        [Switch]$Raw,
        [validatescript(
            {
                if (-not (Get-Command $_ -ErrorAction SilentlyContinue)) {
                    throw "Could not find command at GitPath [$_]"
                }
                $true
            }
        )]
        [String]$GitPath = 'git'
    )

    Begin {
        function GetFullPath ([string]$Path) {
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

        $Path = GetFullPath $Path
        if (!$PSBoundParameters.ContainsKey('GitPath')) {
            $GitPath = (Get-Command $GitPath -ErrorAction Stop)[0].Path
        }
        $Command = $GitPath
    }

    Process {
        # http://stackoverflow.com/questions/8761888/powershell-capturing-standard-out-and-error-with-start-process
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = $GitPath
        $pinfo.CreateNoWindow = $NoWindow
        $pinfo.RedirectStandardError = $RedirectStandardError
        $pinfo.RedirectStandardOutput = $RedirectStandardOutput
        $pinfo.UseShellExecute = $UseShellExecute
        $pinfo.WorkingDirectory = $Path
        if ($PSBoundParameters.ContainsKey('Arguments')) {
            $pinfo.Arguments = $Arguments
            $Command = "$Command $Arguments"
        }
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $pinfo
        $null = $p.Start()
        $p.WaitForExit()
        if ($Quiet) {
            return
        }
        else {
            #there was a newline in output...
            if ($stdout = $p.StandardOutput.ReadToEnd()) {
                if ($split) {
                    $stdout = $stdout -split "`n"  | Where {$_}
                }
                $stdout = foreach ($item in @($stdout)) {
                    $item.trim()
                }
            }
            if ($stderr = $p.StandardError.ReadToEnd()) {
                if ($split) {
                    $stderr = $stderr -split "`n" | Where {$_}
                }
                $stderr = foreach ($item in @($stderr)) {
                    $item.trim()
                }
            }

            if ($Raw) {
                [pscustomobject]@{
                    Command = $Command
                    Output  = $stdout
                    Error   = $stderr
                }
            }
            else {
                if ($stdout) {
                    $stdout
                }
                if ($stderr) {
                    Write-Error $stderr.trim()
                }
            }
        }
    }
}
