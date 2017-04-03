function Add-TestResultToAppveyor {
    <#
    .SYNOPSIS
        Upload test results to AppVeyor

    .DESCRIPTION
        Upload test results to AppVeyor

    .EXAMPLE
        Add-TestResultToAppVeyor -TestFile C:\testresults.xml

    .LINK
        https://github.com/RamblingCookieMonster/BuildHelpers

    .LINK
        about_BuildHelpers
    #>
    [CmdletBinding()]
    [OutputType([void])]
    Param (
        # Appveyor Job ID
        [String]
        $APPVEYOR_JOB_ID = $Env:APPVEYOR_JOB_ID,

        [ValidateSet('mstest','xunit','nunit','nunit3','junit')]
        $ResultType = 'nunit',

        # List of files to be uploaded
        [Parameter(Mandatory,
                   Position,
                   ValueFromPipeline,
                   ValueFromPipelineByPropertyName,
                   ValueFromRemainingArguments
        )]
        [Alias("FullName")]
        [string[]]
        $TestFile
    )

    begin {
            $wc = New-Object 'System.Net.WebClient'
    }

    process {
        foreach ($File in $TestFile) {
            if (Test-Path $File) {
                Write-Verbose "Uploading $File for Job ID: $APPVEYOR_JOB_ID"
                $wc.UploadFile("https://ci.appveyor.com/api/testresults/$ResultType/$($APPVEYOR_JOB_ID)", $File)
            }
        }
    }

    end {
        $wc.Dispose()
    }
}