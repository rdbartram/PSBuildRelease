#requires -module PowershellGet

Param (
    [Parameter(Position = 0)]
    $Tasks,

    [Parameter()]
    [string]
    $ProjectName = (Get-Content $PSScriptRoot\Manifest.json -Raw | ConvertFrom-Json).ModuleInfo.Name,

    [Parameter()]
    $ProjectPath = (Join-Path (Get-Location) "src"),

    [Parameter()]
    [String]
    $BuildOutput = "BuildOutput",

    [Parameter()]
    [switch]
    $NoNuget,

    [Parameter()]
    [String[]]
    $GalleryRepository,

    [Parameter()]
    [Uri]
    $GalleryProxy,

    [Parameter()]
    [switch]
    $ResolveDependency
)

begin {
    Import-Module Microsoft.PowerShell.Utility, Microsoft.PowerShell.Security -ErrorAction SilentlyContinue
    Get-PackageProvider | Out-Null

    $oldpaths = $env:PSModulePath
    $env:PSModulePath = @(
        (Join-Path $PSScriptRoot "Dependencies"),
        (Join-Path $PSScriptRoot "src\Dependencies")
    ) -join ';'

    $dependencyPaths = (Join-Path $PSScriptRoot "Dependencies")

    foreach ($dependencyPath in $dependencyPaths) {
        if (-not (Test-Path $dependencyPath -PathType Container)) {
            New-Item $dependencyPath -Force -ItemType Directory | Out-Null
        }
    }

    if (![io.path]::IsPathRooted($BuildOutput)) {
        $BuildOutput = Join-Path -Path $PSScriptRoot -ChildPath $BuildOutput
    }

    function Resolve-Dependency {
        [CmdletBinding()]
        param()

        if (-not $NoNuget.IsPresent -and !(Get-PackageProvider -Name NuGet -ForceBootstrap)) {
            $providerBootstrapParams = @{
                Name           = 'nuget'
                force          = $true
                ForceBootstrap = $true
            }
            if ($PSBoundParameters.ContainsKey('verbose')) { $providerBootstrapParams.add('verbose', $verbose) }
            if ($GalleryProxy) { $providerBootstrapParams.Add('Proxy', $GalleryProxy) }
            $null = Install-PackageProvider @providerBootstrapParams
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        }

        if (!(Get-Module -Listavailable PSDepend)) {
            Write-Verbose "BootStrapping PSDepend"
            "Parameter $BuildOutput" | Write-Verbose
            $savePSDependParams = @{
                Name = 'PSDepend', 'PowershellGet'
                Path = "$PSScriptRoot\Dependencies"
            }
            if ($PSBoundParameters.ContainsKey('verbose')) { $savePSDependParams.add('verbose', $verbose) }
            if ($GalleryRepository) { $savePSDependParams.Add('Repository', $GalleryRepository) }
            if ($GalleryProxy) { $savePSDependParams.Add('Proxy', $GalleryProxy) }
            if ($GalleryCredential) { $savePSDependParams.Add('ProxyCredential', $GalleryCredential) }
            Save-Module @savePSDependParams
        }

        $DependencyInputObject = Import-PowerShellDataFile (Join-Path $PSScriptRoot "PSDepend.build.psd1")

        if ($null -ne $env:SYSTEM_ACCESSTOKEN) {
            $DependencyInputObject.BR.Name = $DependencyInputObject.BR.Name.Replace("https://", "https://$env:BuildServiceAccountId:$env:SYSTEM_ACCESSTOKEN`@")
        }

        $PSDependParams = @{
            Force       = $true
            InputObject = $DependencyInputObject
            Install     = $true
            Target      = "$PSScriptRoot\Dependencies"
        }

        ##### HACK for psdepend #####
        $map = Get-Item "$PSScriptRoot\Dependencies\PSDepend\*\PSDependMap.psd1"
        $newmap = (Get-Content $map) -replace "Supports = 'windows'$", "Supports = 'windows', 'core'"
        Set-Content -path $map -Value $newmap -Force
        #############################

        $null = Invoke-PSDepend @PSDependParams
        Write-Verbose "Project Bootstrapped, returning to Invoke-Build"
    }

    if ($ResolveDependency) {
        Write-Host "Resolving Dependencies... [this can take a moment]"
        $params = @{ }
        if ($PSboundParameters.ContainsKey('verbose')) {
            $params.Add('verbose', $verbose)
        }
        Resolve-Dependency @Params
    }
}

process {
    if ($MyInvocation.ScriptName -notlike '*Invoke-Build.ps1') {
        $PSBoundParameters.Remove("ResolveDependency") | Out-Null
        Invoke-Build $Tasks $MyInvocation.MyCommand.Path @PSBoundParameters
        return
    }

    task ResolveDependencies {
        Write-Host "Resolving Dependencies... [this can take a moment]"
        $params = @{ }
        if ($PSboundParameters.ContainsKey('Verbose')) {
            $params.Add('Verbose', $Verbose)
        }
        Resolve-Dependency @params
    }

    $buildFiles = Get-Item $PSScriptRoot\.build\* -Include *.ps1
    foreach ($buildFile in $buildFiles) {
        "Importing file $($buildFile.BaseName)" | Write-Verbose
        . $buildFile.FullName
    }
}

end {
    $env:PSModulePath = $oldpaths
}
