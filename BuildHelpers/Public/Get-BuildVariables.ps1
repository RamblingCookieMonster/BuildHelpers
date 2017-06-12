function Get-BuildVariables {
    <#
    .SYNOPSIS
        Normalize build system variables

    .FUNCTIONALITY
        CI/CD

    .DESCRIPTION
        Normalize build system variables

        Each build system exposes common variables it's own unique way, if at all.
        This function was written to enable more portable builds, and
            to avoid tightly coupling your build scripts with your build system

            Gathers from:
                AppVeyor
                GitLab CI
                Jenkins
                Teamcity
                VTFS
                Bamboo
                GoCD

            For Teamcity the VCS Checkout Mode needs to be to checkout files on agent. 
            Since TeamCity 10.0, this is the default setting for the newly created build configurations.
            
            Git needs to be available on the agent for this.  

            Produces:
                BuildSystem: Build system we're running under
                ProjectPath: Project root for cloned repo
                BranchName: git branch for this build
                CommitMessage: git commit message for this build
                BuildNumber: Build number provided by the CI system

    .PARAMETER Path
        Path to project root. Defaults to the current working path

    .NOTES
        We assume you are in the project root, for several of the fallback options

    .EXAMPLE
        Get-BuildVariables

    .LINK
        https://github.com/RamblingCookieMonster/BuildHelpers

    .LINK
        Get-ProjectName

    .LINK
        Set-BuildEnvironment

    .LINK
        about_BuildHelpers
    #>
    [cmdletbinding()]
    param(
        $Path = $PWD.Path
    )

    $Path = ( Resolve-Path $Path ).Path
    $Environment = Get-Item ENV:
    $IsGitRepo = Test-Path $( Join-Path $Path .git )

    $tcProperties = Get-TeamCityProperties # Teamcity has limited ENV: values but dumps the build configuration in a properties file.

    # Determine the build system:
    $BuildSystem = switch ($Environment.Name)
    {
        'APPVEYOR_BUILD_FOLDER' { 'AppVeyor'; break }
        'GITLAB_CI'             { 'GitLab CI' ; break }
        'JENKINS_URL'           { 'Jenkins'; break }
        'BUILD_REPOSITORY_URI'  { 'VSTS'; break }
        'TEAMCITY_VERSION'      { 'Teamcity' ; break }
        'BAMBOO_BUILDKEY'       { 'Bamboo'; break }
        'GOCD_SERVER_URL'       { 'GoCD'; break }
    }
    if(-not $BuildSystem)
    {
        $BuildSystem = 'Unknown'
    }

    # Find the build folder based on build system
    $BuildRoot = switch ($Environment.Name)
    {
        'APPVEYOR_BUILD_FOLDER'          { (Get-Item -Path "ENV:$_").Value; break } # AppVeyor
        'CI_PROJECT_DIR'                 { (Get-Item -Path "ENV:$_").Value; break } # GitLab CI
        'WORKSPACE'                      { (Get-Item -Path "ENV:$_").Value; break } # Jenkins Jenkins... seems generic.
        'BUILD_REPOSITORY_LOCALPATH'     { (Get-Item -Path "ENV:$_").Value; break } # VSTS (Visual studio team services)
        'BAMBOO_BUILD_WORKING_DIRECTORY' { (Get-Item -Path "ENV:$_").Value; break } # Bamboo
    }
    if(-not $BuildRoot)
    {
        if ($BuildSystem -eq 'Teamcity') {
            $BuildRoot = $tcProperties['teamcity.build.checkoutDir']
        } else {
            # Assumption: this function is defined in a file at the root of the build folder
            $BuildRoot = $Path
        }
    }

    # Find the git branch
    $BuildBranch = switch ($Environment.Name)
    {
        'APPVEYOR_REPO_BRANCH'         { (Get-Item -Path "ENV:$_").Value; break } # AppVeyor
        'CI_BUILD_REF_NAME'            { (Get-Item -Path "ENV:$_").Value; break } # GitLab CI
        'GIT_BRANCH'                   { (Get-Item -Path "ENV:$_").Value; break } # Jenkins
        'BUILD_SOURCEBRANCHNAME'       { (Get-Item -Path "ENV:$_").Value; break } # VSTS
        'BAMBOO_REPOSITORY_GIT_BRANCH' { (Get-Item -Path "ENV:$_").Value; break } # Bamboo
    }
    if(-not $BuildBranch)
    {
        if($IsGitRepo)
        {
            # Using older than 1.6.3 in your build system? Yuck
            # Thanks to earl: http://stackoverflow.com/a/1418022/3067642
            $BuildBranch = Invoke-Git -Arguments "rev-parse --abbrev-ref HEAD" -Path $Path
        }
    }

    # Find the git commit message
    $CommitMessage = switch ($Environment.Name)
    {
        'APPVEYOR_REPO_COMMIT_MESSAGE' {
            "$env:APPVEYOR_REPO_COMMIT_MESSAGE $env:APPVEYOR_REPO_COMMIT_MESSAGE_EXTENDED"
            break
        }
        'CI_BUILD_REF' {
            if($IsGitRepo)
            {
                Invoke-Git -Arguments "log --format=%B -n 1 $( (Get-Item -Path "ENV:$_").Value )" -Path $Path
                break
            } # Gitlab - thanks to mipadi http://stackoverflow.com/a/3357357/3067642
        }
        'GIT_COMMIT' {
            if($IsGitRepo)
            {
                Invoke-Git  -Arguments "log --format=%B -n 1 $( (Get-Item -Path "ENV:$_").Value )" -Path $Path
                break
            } # Jenkins - thanks to mipadi http://stackoverflow.com/a/3357357/3067642
        }
        'BUILD_SOURCEVERSION' {
            if($IsGitRepo)
            {
                Invoke-Git -Arguments "log --format=%B -n 1 $( (Get-Item -Path "ENV:$_").Value )" -Path $Path
                break
            } # VSTS (https://www.visualstudio.com/en-us/docs/build/define/variables#)
        }
        'BUILD_VCS_NUMBER' {
            if($IsGitRepo)
            {
                Invoke-Git -Arguments "log --format=%B -n 1 $( (Get-Item -Path "ENV:$_").Value )" -Path $Path
                break
            } # Teamcity https://confluence.jetbrains.com/display/TCD10/Predefined+Build+Parameters
        }
        'BAMBOO_REPOSITORY_REVISION_NUMBER' {
            if($IsGitRepo)
            {
                Invoke-Git -Arguments "log --format=%B -n 1 $( (Get-Item -Path "ENV:$_").Value )" -Path $Path
                break
            } # Bamboo https://confluence.atlassian.com/bamboo/bamboo-variables-289277087.html
        }        
    }
    if(-not $CommitMessage)
    {
        if($IsGitRepo)
        {
            $CommitMessage = Invoke-Git -Arguments "log --format=%B -n 1" -Path $Path
        }
    }

    # Build number
    $BuildNumber = switch ($Environment.Name)
    {
        'APPVEYOR_BUILD_NUMBER' { (Get-Item -Path "ENV:$_").Value; break } # AppVeyor
        'CI_BUILD_ID   '        { (Get-Item -Path "ENV:$_").Value; break } # GitLab CI - not perfect https://gitlab.com/gitlab-org/gitlab-ce/issues/3691
        'BUILD_NUMBER'          { (Get-Item -Path "ENV:$_").Value; break } # Jenkins, Teamcity ... seems generic.
        'BUILD_BUILDNUMBER'     { (Get-Item -Path "ENV:$_").Value; break } # VSTS
        'BAMBOO_BUILDNUMBER'    { (Get-Item -Path "ENV:$_").Value; break } # Bamboo
        'GOCD_PIPELINE_COUNTER' { (Get-Item -Path "ENV:$_").Value; break } # GoCD
    }
    if(-not $BuildNumber)
    {
        $BuildNumber = 0
    }

    [pscustomobject]@{
        BuildSystem = $BuildSystem
        ProjectPath = $BuildRoot
        BranchName = $BuildBranch
        CommitMessage = $CommitMessage
        BuildNumber = $BuildNumber
    }
}