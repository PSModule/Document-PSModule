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
    [pscustomobject]@{
        ModuleName              = $ModuleName
        ModuleSourceFolderPath  = $ModuleSourceFolderPath
        ModulesOutputFolderPath = $ModulesOutputFolderPath
        DocsOutputFolderPath    = $DocsOutputFolderPath
    } | Format-List | Out-String

    if (-not (Test-Path -Path $ModuleSourceFolderPath)) {
        Write-Error "Source folder not found at [$ModuleSourceFolderPath]"
        exit 1
    }
    $moduleSourceFolder = Get-Item -Path $ModuleSourceFolderPath
    $moduleOutputFolder = New-Item -Path $ModulesOutputFolderPath -Name $ModuleName -ItemType Directory -Force
    $docsOutputFolder = New-Item -Path $DocsOutputFolderPath -ItemType Directory -Force

    Write-Host '::group::Build docs - Generate markdown help - Raw'
    Install-PSModule -Path $ModuleOutputFolder
    $moduleInfo = Import-Module -Name $ModuleName -PassThru -Verbose:$false -Force

    # Get all exported commands from the module
    $commands = $moduleInfo.ExportedCommands.Values | Where-Object { $_.CommandType -ne 'Alias' }

    Write-Host "::group::Found $($commands.Count) commands to process"

    foreach ($command in $commands) {
        try {
            Write-Host "$($command.Name)" -NoNewline
            $params = @{
                CommandInfo    = $command
                OutputFolder   = $docsOutputFolder
                Encoding       = 'utf8'
                ProgressAction = 'SilentlyContinue'
                ErrorAction    = 'Stop'
                Force          = $true
            }
            $null = New-MarkdownCommandHelp @params
            Write-Host " - $($PSStyle.Foreground.Green)✓$($PSStyle.Reset)"
        } catch {
            Write-Host " - $($PSStyle.Foreground.Red)✗$($PSStyle.Reset)"
            $_
        }
    }

    Write-Host '::group::Build docs - Generated files'
    Get-ChildItem -Path $docsOutputFolder -Recurse | Select-Object -ExpandProperty FullName

    Get-ChildItem -Path $docsOutputFolder -Recurse -Force -Include '*.md' | ForEach-Object {
        $fileName = $_.Name
        Write-Host "::group:: - [$fileName]"
        Show-FileContent -Path $_
    }

    Write-Host '::group::Build docs - Fix markdown code blocks'
    Get-ChildItem -Path $docsOutputFolder -Recurse -Force -Include '*.md' | ForEach-Object {
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
    Get-ChildItem -Path $docsOutputFolder -Recurse -Force -Include '*.md' | ForEach-Object {
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
    Get-ChildItem -Path $docsOutputFolder -Recurse -Force -Include '*.md' | ForEach-Object {
        $file = $_
        $relPath = [System.IO.Path]::GetRelativePath($docsOutputFolder, $file.FullName)
        Write-Host " - $relPath"
        Write-Host "   Path:     $file"

        # find the source code file that matches the markdown file
        $scriptPath = Get-ChildItem -Path $PublicFunctionsFolder -Recurse -Force | Where-Object { $_.Name -eq ($file.BaseName + '.ps1') }
        Write-Host "   PS1 path: $scriptPath"
        $docsFilePath = ($scriptPath.FullName).Replace($PublicFunctionsFolder.FullName, $docsOutputFolder).Replace('.ps1', '.md')
        Write-Host "   MD path:  $docsFilePath"
        $docsFolderPath = Split-Path -Path $docsFilePath -Parent
        $null = New-Item -Path $docsFolderPath -ItemType Directory -Force
        Move-Item -Path $file.FullName -Destination $docsFilePath -Force
    }

    Write-Host '::group::Build docs - Fix frontmatter title'
    Get-ChildItem -Path $docsOutputFolder -Recurse -Force -Include '*.md' | ForEach-Object {
        $content = Get-Content -Path $_.FullName -Raw
        # Replace 'title:' with 'ms.title:' in frontmatter only (between --- markers)
        $content = $content -replace '(?s)^(---.*?)title:(.*?---)', '$1ms.title:$2'
        $content | Set-Content -Path $_.FullName
    }

    Write-Host '::group::Build docs - Move markdown files from public functions folder to docs output folder'
    Get-ChildItem -Path $PublicFunctionsFolder -Recurse -Force -Include '*.md' | ForEach-Object {
        $file = $_
        $relPath = [System.IO.Path]::GetRelativePath($PublicFunctionsFolder.FullName, $file.FullName)
        Write-Host " - $relPath"
        Write-Host "   Path:     $file"

        $docsFilePath = ($file.FullName).Replace($PublicFunctionsFolder.FullName, $docsOutputFolder)
        Write-Host "   MD path:  $docsFilePath"
        $docsFolderPath = Split-Path -Path $docsFilePath -Parent
        $null = New-Item -Path $docsFolderPath -ItemType Directory -Force
        Move-Item -Path $file.FullName -Destination $docsFilePath -Force
    }

    Write-Host '────────────────────────────────────────────────────────────────────────────────'
    Get-ChildItem -Path $docsOutputFolder -Recurse -Force -Include '*.md' | ForEach-Object {
        $fileName = $_.Name
        Write-Host "::group:: - [$fileName]"
        Show-FileContent -Path $_
    }
}
