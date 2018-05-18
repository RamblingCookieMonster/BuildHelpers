function Set-ShieldsIoBadge {
    <#
    .SYNOPSIS
        Modifies the link to a https://shields.io badge in a .md file. Can be used as part of a CI pipeline to update the status of 
        badges such as Code Coverage.

    .FUNCTIONALITY
        CI/CD

    .DESCRIPTION
        This cmdlet can be used to update the link to a https://shields.io badge that has been created in a file such as readme.md.
        
        To use this function You need to have initially added the badge to your readme.md or specified file by adding the following
         string (ensuring 'Subject' matches what you specify for -Subject):

        ![Subject]()
    
    .PARAMETER Subject
        The label to assign to the badge. Default 'Build'.
    
    .PARAMETER Status
        The status text of value to assign to the badge. Default: 0.

    .PARAMETER Color
        The color to assign to the badge. If status is set to 0 - 100 and this parameter is not specified, the color is set 
        automatically to either green, yellow, orange or red depending on the value, or light grey if it is not a 0 - 100 value.

    .PARAMETER AsPercentage
        Switch: Use to add a percentage sign after whatever you provide for -Status.

    .PARAMETER Path
        Path to the text file to update. By default this is $Env:BHProjectPath\Readme.md

    .EXAMPLE    
        Set-ShieldsIoBadge -Subject 'Coverage' -Status ([math]::floor(100 - (($PesterResults.CodeCoverage.NumberOfCommandsMissed / $PesterResults.CodeCoverage.NumberOfCommandsAnalyzed) * 100))) -AsPercentage

    .LINK
        http://wragg.io/add-a-code-coverage-badge-to-your-powershell-deployment-pipeline/

    .LINK
        https://github.com/RamblingCookieMonster/BuildHelpers

    .LINK
        about_BuildHelpers
    #>
    [cmdletbinding(supportsshouldprocess)]
    param(
        [string]
        $Subject = 'Build',
        
        $Status = 0,
        
        [string]
        $Color,

        [switch]
        $AsPercentage,
        
        [string]
        $Path = "$Env:BHProjectPath\Readme.md"
    )
    Process
    {
        if (-not $Color)
        { 
            $Color = switch ($Status)
            {
                {$_ -in 90..100 -or $_ -eq 'Pass'} { 'brightgreen' }
                {$_ -in 75..89}                    { 'yellow' }
                {$_ -in 60..74}                    { 'orange' }
                {$_ -in 0..59 -or $_ -eq 'Fail'}   { 'red' }
                default                            { 'lightgrey' }
            }
        }

        if ($AsPercentage)
        {
            $Percent = '%25'
        }

        if ($PSCmdlet.ShouldProcess($Path))
        {
            $ReadmeContent = (Get-Content $Path)
            $ReadmeContent = $ReadmeContent -replace "!\[$($Subject)\].+\)", "![$($Subject)](https://img.shields.io/badge/$Subject-$Status$Percent-$Color.svg)" 
            $ReadmeContent | Set-Content -Path $Path
        }
    }
}