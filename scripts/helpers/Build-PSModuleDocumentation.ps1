function Build-PSModuleDocumentation {
    <#
    .SYNOPSIS
    Builds a module.

    .DESCRIPTION
    Builds a module.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost', '', Scope = 'Function',
        Justification = 'Want to just write to the console, not the pipeline.'
    )]
    param(
        # Name of the module.
        [Parameter(Mandatory)]
        [string] $ModuleName,

        # Path to the folder where the modules are located.
        [Parameter(Mandatory)]
        [string] $ModuleSourceFolderPath,

        # Path to the folder where the built modules are outputted.
        [Parameter(Mandatory)]
        [string] $ModulesOutputFolderPath,

        # Path to the folder where the documentation is outputted.
        [Parameter(Mandatory)]
        [string] $DocsOutputFolderPath
    )

    Write-Host "::group::Documenting module [$ModuleName]"
    Write-Host "Source path:          [$ModuleSourceFolderPath]"
    if (-not (Test-Path -Path $ModuleSourceFolderPath)) {
        Write-Error "Source folder not found at [$ModuleSourceFolderPath]"
        exit 1
    }
    $moduleSourceFolder = Get-Item -Path $ModuleSourceFolderPath
    Write-Host "Module source folder: [$moduleSourceFolder]"

    $moduleOutputFolder = New-Item -Path $ModulesOutputFolderPath -Name $ModuleName -ItemType Directory -Force
    Write-Host "Module output folder: [$moduleOutputFolder]"

    $docsOutputFolder = New-Item -Path $DocsOutputFolderPath -ItemType Directory -Force
    Write-Host "Docs output folder:   [$docsOutputFolder]"

    Write-Host '::group::Build docs - Generate markdown help'
    Import-PSModule -Path $ModuleOutputFolder
    Write-Host ($ModuleName | Get-Module)
    $null = New-MarkdownHelp -Module $ModuleName -OutputFolder $DocsOutputFolder -Force -Verbose
    Get-ChildItem -Path $DocsOutputFolder -Recurse -Force -Include '*.md' | ForEach-Object {
        $fileName = $_.Name
        Write-Host "::group:: - [$fileName]"
        Show-FileContent -Path $_
    }

    Write-Host '::group::Build docs - Fix markdown code blocks'
    Get-ChildItem -Path $DocsOutputFolder -Recurse -Force -Include '*.md' | ForEach-Object {
        $content = Get-Content -Path $_.FullName
        $fixedOpening = $false
        $newContent = @()
        foreach ($line in $content) {
            if ($line -match '^```$' -and -not $fixedOpening) {
                $line = $line -replace '^```$', '```powershell'
                $fixedOpening = $true
            } elseif ($line -match '^```.+$') {
                $fixedOpening = $true
            } elseif ($line -match '^```$') {
                $fixedOpening = $false
            }
            $newContent += $line
        }
        $newContent | Set-Content -Path $_.FullName
    }

    Write-Host '::group::Build docs - Fix markdown escape characters'
    Get-ChildItem -Path $DocsOutputFolder -Recurse -Force -Include '*.md' | ForEach-Object {
        $content = Get-Content -Path $_.FullName -Raw
        $content = $content -replace '\\`', '`'
        $content = $content -replace '\\\[', '['
        $content = $content -replace '\\\]', ']'
        $content = $content -replace '\\\<', '<'
        $content = $content -replace '\\\>', '>'
        $content = $content -replace '\\\\', '\'
        $content | Set-Content -Path $_.FullName
    }

    Write-Host '::group::Build docs - Structure markdown files to match source files'
    $PublicFunctionsFolder = Join-Path $ModuleSourceFolder.FullName 'functions\public' | Get-Item
    Get-ChildItem -Path $DocsOutputFolder -Recurse -Force -Include '*.md' | ForEach-Object {
        $file = $_
        Write-Host "Processing:        $file"

        # find the source code file that matches the markdown file
        $scriptPath = Get-ChildItem -Path $PublicFunctionsFolder -Recurse -Force | Where-Object { $_.Name -eq ($file.BaseName + '.ps1') }
        Write-Host "Found script path: $scriptPath"
        $docsFilePath = ($scriptPath.FullName).Replace($PublicFunctionsFolder.FullName, $DocsOutputFolder.FullName).Replace('.ps1', '.md')
        Write-Host "Doc file path:     $docsFilePath"
        $docsFolderPath = Split-Path -Path $docsFilePath -Parent
        New-Item -Path $docsFolderPath -ItemType Directory -Force
        Move-Item -Path $file.FullName -Destination $docsFilePath -Force
    }
    # Get the MD files that are in the public functions folder and move them to the same place in the docs folder
    Get-ChildItem -Path $PublicFunctionsFolder -Recurse -Force -Include '*.md' | ForEach-Object {
        $file = $_
        Write-Host "Processing:        $file"
        $docsFilePath = ($file.FullName).Replace($PublicFunctionsFolder.FullName, $DocsOutputFolder.FullName)
        Write-Host "Doc file path:     $docsFilePath"
        $docsFolderPath = Split-Path -Path $docsFilePath -Parent
        New-Item -Path $docsFolderPath -ItemType Directory -Force
        Move-Item -Path $file.FullName -Destination $docsFilePath -Force
    }

    Get-ChildItem -Path $DocsOutputFolder -Recurse -Force -Include '*.md' | ForEach-Object {
        $fileName = $_.Name
        $hash = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash
        Write-Host "::group:: - [$fileName] - [$hash]"
        Show-FileContent -Path $_
    }
}
