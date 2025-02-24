[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost', '',
    Justification = 'Want to just write to the console, not the pipeline.'
)]
[CmdletBinding()]
param()

#Requires -Modules Utilities

$path = (Join-Path -Path $PSScriptRoot -ChildPath 'helpers') | Get-Item | Resolve-Path -Relative
LogGroup "Loading helper scripts from [$path]" {
    Get-ChildItem -Path $path -Filter '*.ps1' -Recurse | Resolve-Path -Relative | ForEach-Object {
        Write-Host "$_"
        . $_
    }
}

LogGroup 'Loading inputs' {
    $moduleName = ($env:GITHUB_ACTION_INPUT_Name | IsNullOrEmpty) ? $env:GITHUB_REPOSITORY_NAME : $env:GITHUB_ACTION_INPUT_Name
    Write-Host "Module name:         [$moduleName]"

    $moduleSourceFolderPath = Resolve-Path -Path "$env:GITHUB_ACTION_INPUT_Path/src"
    if (-not (Test-Path -Path $moduleSourceFolderPath)) {
        throw "Module path [$moduleSourceFolderPath] does not exist."
    }
    Write-Host "Module source path:  [$moduleSourceFolderPath]"

    $modulesOutputFolderPath = Join-Path -Path $env:GITHUB_ACTION_INPUT_Path 'outputs/module'
    Write-Host "Module output path:  [$modulesOutputFolderPath]"
    $docsOutputFolderPath = Join-Path -Path $env:GITHUB_ACTION_INPUT_Path 'outputs/docs'
    Write-Host "Docs output path:    [$docsOutputFolderPath]"
}

$params = @{
    ModuleName              = $moduleName
    ModuleSourceFolderPath  = $moduleSourceFolderPath
    ModulesOutputFolderPath = $modulesOutputFolderPath
    DocsOutputFolderPath    = $docsOutputFolderPath
}

Build-PSModuleDocumentation @params
