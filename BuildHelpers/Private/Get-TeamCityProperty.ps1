function Get-TeamCityProperty
{
    <#
    .SYNOPSIS
    Loads TeamCity system build properties into a hashtable
    Doesn't do anything if not running under TeamCity

    .DESCRIPTION
    Teamcity generates a build properties file and stores the location in the environent
    variable TEAMCITY_BUILD_PROPERTIES_FILE.

    Loads the TeamCity system build properties into a hashtable.

    .PARAMETER propertiesfile
    Path to properties xml file. Defaults to environent
    variable TEAMCITY_BUILD_PROPERTIES_FILE.

    .NOTES
    We assume you are in the project root, for several of the fallback options

    .EXAMPLE
    Get-TeamCityProperty

    .LINK
    https://gist.github.com/piers7/6432985

    .LINK
    Get-BuildVariable
    #>
    [OutputType([hashtable])]
    param(
        [string]$propertiesfile = $env:TEAMCITY_BUILD_PROPERTIES_FILE + '.xml'
    )

    if(![String]::IsNullOrEmpty($env:TEAMCITY_VERSION))
    {
        Write-Verbose -Message "Loading TeamCity properties from $propertiesfile"
        $propertiesfile = (Resolve-Path $propertiesfile).Path

        $buildPropertiesXml = New-Object -TypeName System.Xml.XmlDocument
        $buildPropertiesXml.XmlResolver = $null
        $buildPropertiesXml.Load($propertiesfile)

        $buildProperties = @{}
        foreach($entry in $buildPropertiesXml.SelectNodes('//entry'))
        {
            $buildProperties[$entry.Key] = $entry.'#text'
        }

        Write-Output -InputObject $buildProperties
    }
}
