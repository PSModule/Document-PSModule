[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost', '',
    Justification = 'Want to just write to the console, not the pipeline.'
)]
[CmdletBinding()]
param()

$PSStyle.OutputRendering = 'Ansi'

'platyPS' | ForEach-Object {
    Install-PSResource -Name $_ -WarningAction SilentlyContinue -TrustRepository -Repository PSGallery
    Import-Module -Name $_
}

$path = (Join-Path -Path $PSScriptRoot -ChildPath 'helpers') | Get-Item | Resolve-Path -Relative
Write-Host "::group::Loading helper scripts from [$path]"
Get-ChildItem -Path $path -Filter '*.ps1' -Recurse | Resolve-Path -Relative | ForEach-Object {
    Write-Host "$_"
    . $_
}

Write-Host '::group::Loading inputs'
$env:GITHUB_REPOSITORY_NAME = $env:GITHUB_REPOSITORY -replace '.+/'
$moduleName = [string]::IsNullOrEmpty($env:GITHUB_ACTION_INPUT_Name) ? $env:GITHUB_REPOSITORY_NAME : $env:GITHUB_ACTION_INPUT_Name
$moduleSourceFolderPath = Resolve-Path -Path 'src' | Select-Object -ExpandProperty Path
$modulesOutputFolderPath = Join-Path -Path . -ChildPath 'outputs/module'
$docsOutputFolderPath = Join-Path -Path . -ChildPath 'outputs/docs'

$params = @{
    ModuleName              = $moduleName
    ModuleSourceFolderPath  = $moduleSourceFolderPath
    ModulesOutputFolderPath = $modulesOutputFolderPath
    DocsOutputFolderPath    = $docsOutputFolderPath
}

[pscustomobject]$params | Format-List | Out-String

Build-PSModuleDocumentation @params
