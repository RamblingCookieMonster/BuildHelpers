function Set-CodeCoverageBadge {
    <#
    .SYNOPSIS
        Sets the colour and percentage values of the code coverage badge displayed in readme.md or other specified file.

    .FUNCTIONALITY
        CI/CD

    .DESCRIPTION
        Sets the colour and percentage values of the code coverage badge displayed in readme.md or other specified file.
        Typically this would be used after using Invoke-Pester with the -CodeCoverage parameter and returning the coverage
        result values via -PassThru to a variable (such as $PesterResults).

        You also need to have initially added the badge to your readme.md or specified file by adding the following string:

        ![Test Coverage](https://img.shields.io/badge/coverage0%25-red.svg)

    .PARAMETER CodeCoverage
        An integer value for the current percentage of code coverage.
    
    .PARAMETER TextFilePath
        Path to the text file to update. By default this is $Env:BHProjectPath\Readme.md
    
    .PARAMETER BadgeRegex
        A regular expression used to locate the code coverage badge string to update. Default: '!\[Test Coverage\].+\)'

    .EXAMPLE    
        Set-CodeCoverageBadge -CodeCoverage ([math]::floor(100 - (($PesterResults.CodeCoverage.NumberOfCommandsMissed / $PesterResults.CodeCoverage.NumberOfCommandsAnalyzed) * 100)))

    .LINK
        http://wragg.io/add-a-code-coverage-badge-to-your-powershell-deployment-pipeline/

    .LINK
        https://github.com/RamblingCookieMonster/BuildHelpers

    .LINK
        about_BuildHelpers
    #>
    [cmdletbinding(supportsshouldprocess)]
    param(
        [int]
        $CodeCoverage = 0,
        
        [string]
        $TextFilePath = "$Env:BHProjectPath\Readme.md",
        
        [string]
        $BadgeRegex = '!\[Test Coverage\].+\)'
    )
    Process
    {
        $BadgeColor = switch ($CodeCoverage)
        {
            {$_ -in 90..100} { 'brightgreen' }
            {$_ -in 75..89}  { 'yellow' }
            {$_ -in 60..74}  { 'orange' }
            default          { 'red' }
        }
    
        if ($PSCmdlet.ShouldProcess($TextFilePath))
        {
            $ReadmeContent = (Get-Content $TextFilePath)
            $ReadmeContent = $ReadmeContent -replace $BadgeRegex, "![Test Coverage](https://img.shields.io/badge/coverage-$CodeCoverage%25-$BadgeColor.svg)" 
            $ReadmeContent | Set-Content -Path $TextFilePath
        }
    }
}
