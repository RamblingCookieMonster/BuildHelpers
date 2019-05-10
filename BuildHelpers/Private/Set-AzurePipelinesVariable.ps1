function Set-AzurePipelinesVariable {
    <#
    .SYNOPSIS
        Set a envrionment variable in VSTS/Azure Pipelines that will persist between tasks

    .DESCRIPTION
        This command uses the VSTS/Azure Pipelines command task.setvariable to create an
        envrionment variable which will be available in all following tasks
        within the same stage.

    .EXAMPLE
        Set-AzurePipelinesVariable -Name ProjectName -Value (Get-ProjectName)

    .EXAMPLE
        Set-AzurePipelinesVariable -Name ProjectName -Value (Get-ProjectName) -Secret

    .LINK
        https://github.com/Microsoft/azure-pipelines-tasks/blob/master/docs/authoring/commands.md
    #>
    [CmdletBinding( SupportsShouldProcess = $false )]
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseShouldProcessForStateChangingFunctions', '')]
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSAvoidUsingWriteHost', 'Azure Pipelines does not listen to Out-Host')]
    param (
        # Name of the variable
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        # Value of the variable
        [string]$Value,

        # The value of the variable will be saved as secret and masked out from log.
        # Secret variables are not passed into tasks as environment variables and must be passed as inputs.
        [switch]$Secret
    )

    Process {
        $_secret = ""
        if ($Secret) { $_secret = ";issecret=true" }

        Write-Verbose "storing [$Name] with Azure Pipelines task.setvariable command"
        Write-Host "##vso[task.setvariable variable=$Name$_secret]$Value"
    }
}
