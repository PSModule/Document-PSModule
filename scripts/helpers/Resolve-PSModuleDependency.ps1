function Resolve-PSModuleDependency {
    <#
        .SYNOPSIS
            Resolves module dependencies from a manifest file using Install-PSResource.

        .DESCRIPTION
            Reads a module manifest (PSD1) and for each required module converts the old
            Install-Module parameters (MinimumVersion, MaximumVersion, RequiredVersion)
            into a single NuGet version range string for Install-PSResource's –Version parameter.
            (Note: If RequiredVersion is set, that value takes precedence.)

        .EXAMPLE
            Resolve-PSModuleDependency -ManifestFilePath 'C:\MyModule\MyModule.psd1'
    Installs all modules defined in the manifest file, following PSModuleInfo structure.

        .NOTES
        Should later be adapted to support both pre-reqs, and dependencies.
        Should later be adapted to take 4 parameters sets: specific version ("requiredVersion" | "GUID"), latest version ModuleVersion,
        and latest version within a range MinimumVersion - MaximumVersion.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost', '', Scope = 'Function',
        Justification = 'Want to just write to the console, not the pipeline.'
    )]
    [CmdletBinding()]
    param(
        # The path to the manifest file.
        [Parameter(Mandatory)]
        [string] $ManifestFilePath
    )

    # Helper: Converts the legacy version parameters into a NuGet version range.
    function Convert-VersionSpec {
        param(
            [string]$MinimumVersion,
            [string]$MaximumVersion,
            [string]$RequiredVersion
        )
        if ($RequiredVersion) {
            # Exact match – note that for an exact version, using bracket notation
            # helps ensure that Install-PSResource looks for that version only.
            return "[$RequiredVersion]"
        } elseif ($MinimumVersion -and $MaximumVersion) {
            # Both bounds provided; note that this makes both ends inclusive.
            return "[$MinimumVersion,$MaximumVersion]"
        } elseif ($MinimumVersion) {
            # Only a minimum is provided.
            # Using the notation “[1.0.0.0, ]” ensures a minimum-inclusive search.
            return "[$MinimumVersion, ]"
        } elseif ($MaximumVersion) {
            # Only a maximum is provided; here we use an open lower bound.
            return "(, $MaximumVersion]"
        } else {
            return $null
        }
    }

    Write-Host 'Resolving dependencies'

    $manifest = Import-PowerShellDataFile -Path $ManifestFilePath
    Write-Host " - Reading [$ManifestFilePath]"
    Write-Host " - Found [$($manifest.RequiredModules.Count)] module(s) to install"

    foreach ($requiredModule in $manifest.RequiredModules) {
        $installParams = @{
            TrustRepository = $true
        }

        if ($requiredModule -is [string]) {
            $installParams.Name = $requiredModule
        } else {
            $installParams.Name = $requiredModule.ModuleName

            # Convert legacy version parameters into the new –Version spec.
            $versionSpec = Convert-VersionSpec `
                -MinimumVersion $requiredModule.ModuleVersion `
                -MaximumVersion $requiredModule.MaximumVersion `
                -RequiredVersion $requiredModule.RequiredVersion

            if ($versionSpec) {
                $installParams.Version = $versionSpec
            }
        }

        Write-Host " - [$($installParams.Name)] - Installing module with version spec: $($installParams.Version)"
        $VerbosePreferenceOriginal = $VerbosePreference
        $VerbosePreference = 'SilentlyContinue'

        # Basic retry logic in case of transient errors.
        $retryCount = 5
        $retryDelay = 10
        for ($i = 0; $i -lt $retryCount; $i++) {
            try {
                Install-PSResource @installParams
                break
            } catch {
                Write-Warning "Installation of $($installParams.Name) failed with error: $_"
                if ($i -eq $retryCount - 1) {
                    throw
                }
                Write-Warning "Retrying in $retryDelay seconds..."
                Start-Sleep -Seconds $retryDelay
            }
        }
        $VerbosePreference = $VerbosePreferenceOriginal

        Write-Host " - [$($installParams.Name)] - Importing module"
        $VerbosePreferenceOriginal = $VerbosePreference
        $VerbosePreference = 'SilentlyContinue'
        Import-Module @installParams
        $VerbosePreference = $VerbosePreferenceOriginal
        Write-Host " - [$($installParams.Name)] - Done"
    }
    Write-Host ' - Resolving dependencies - Done'
}
