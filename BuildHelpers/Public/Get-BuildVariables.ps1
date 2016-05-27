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

            Produces:
                BuildSystem: Build system we're running under
                ProjectPath: Project root for cloned repo
                BranchName: git branch for this build
                CommitMessage: git commit message for this build

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

$Environment = Get-Item ENV:
$IsGitRepo = Test-Path $( Join-Path $Path .git )

# Find the build folder based on build system
    $BuildRoot = switch ($Environment.Name)
    {
        'APPVEYOR_BUILD_FOLDER' { (Get-Item -Path "ENV:$_").Value; break } # AppVeyor
        'CI_PROJECT_DIR'        { (Get-Item -Path "ENV:$_").Value; break } # GitLab CI
        'WORKSPACE'             { (Get-Item -Path "ENV:$_").Value; break } # Jenkins Jenkins... seems generic.
    }
    if(-not $BuildRoot)
    {
        # Assumption: this function is defined in a file at the root of the build folder
        $BuildRoot = $PSScriptRoot
    }

# Find the git branch
    $BuildBranch = switch ($Environment.Name)
    {
        'APPVEYOR_REPO_BRANCH'  { (Get-Item -Path "ENV:$_").Value; break } # AppVeyor
        'CI_BUILD_REF_NAME'     { (Get-Item -Path "ENV:$_").Value; break } # GitLab CI
        'GIT_BRANCH'            { (Get-Item -Path "ENV:$_").Value; break } # Jenkins
    }
    if(-not $BuildBranch)
    {
        if($IsGitRepo)
        {
            # Using older than 1.6.3 in your build system? Yuck
            # Thanks to earl: http://stackoverflow.com/a/1418022/3067642
            $BuildBranch = git rev-parse --abbrev-ref HEAD
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
                    git log --format=%B -n 1 $( (Get-Item -Path "ENV:$_").Value )
                    break
                } # Gitlab - thanks to mipadi http://stackoverflow.com/a/3357357/3067642
        }
        'GIT_COMMIT' {
                if($IsGitRepo)
                {
                    git log --format=%B -n 1 $( (Get-Item -Path "ENV:$_").Value )
                    break
                } # Jenkins - thanks to mipadi http://stackoverflow.com/a/3357357/3067642
        }
    }
    if(-not $CommitMessage)
    {
        if($IsGitRepo)
        {
            $CommitMessage = git log --format=%B -n 1
        }
    }

# Determine the build system:
    $BuildSystem = switch ($Environment.Name)
    {
        'APPVEYOR_BUILD_FOLDER' { 'AppVeyor'; break }
        'GITLAB_CI'             { 'GitLab CI' ; break }
        'JENKINS_URL'           { 'Jenkins'; break }
    }
    if(-not $BuildSystem)
    {
        $BuildSystem = 'Unknown'
    }

    [pscustomobject]@{
        BuildSystem = $BuildSystem
        ProjectPath = $BuildRoot
        BranchName = $BuildBranch
        CommitMessage = $CommitMessage
    }
}