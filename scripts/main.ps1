[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost', '',
    Justification = 'Want to just write to the console, not the pipeline.'
)]
[CmdletBinding()]
param()

$PSStyle.OutputRendering = 'Ansi'

'Microsoft.PowerShell.PlatyPS' | ForEach-Object {
    $name = $_
    Write-Output "Installing module: $name"
    $retryCount = 5
    $retryDelay = 10
    for ($i = 0; $i -lt $retryCount; $i++) {
        try {
            Install-PSResource -Name $name -WarningAction SilentlyContinue -TrustRepository -Repository PSGallery
            break
        } catch {
            Write-Warning "Installation of $($psResourceParams.Name) failed with error: $_"
            if ($i -eq $retryCount - 1) {
                throw
            }
            Write-Warning "Retrying in $retryDelay seconds..."
            Start-Sleep -Seconds $retryDelay
        }
    }
    Import-Module -Name $name
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
$showSummaryOnSuccess = $env:GITHUB_ACTION_INPUT_ShowSummaryOnSuccess -eq 'true'
$moduleSourceFolderPath = Resolve-Path -Path 'src' | Select-Object -ExpandProperty Path
$modulesOutputFolderPath = Join-Path -Path . -ChildPath 'outputs/module'
$docsOutputFolderPath = Join-Path -Path . -ChildPath 'outputs/docs'

$params = @{
    ModuleName              = $moduleName
    ModuleSourceFolderPath  = $moduleSourceFolderPath
    ModulesOutputFolderPath = $modulesOutputFolderPath
    DocsOutputFolderPath    = $docsOutputFolderPath
    ShowSummaryOnSuccess    = $showSummaryOnSuccess
}

[pscustomobject]$params | Format-List | Out-String

Build-PSModuleDocumentation @params
