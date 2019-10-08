#requires -module PowershellGet

Param (
    [Parameter(Position = 0)]
    $Tasks,

    [Parameter()]
    [string]
    $ProjectName = (Get-Content (Join-Path (Get-Location) "Manifest.json") -Raw | ConvertFrom-Json).ModuleInfo.Name,

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
    [string]
    $PublishGallery,

    [Parameter()]
    [string]
    $PublishKey,

    [Parameter()]
    [switch]
    $ResolveDependency
)

begin {
    Import-Module Microsoft.PowerShell.Utility, Microsoft.PowerShell.Security -ErrorAction SilentlyContinue
    Get-PackageProvider | Out-Null

    $ProjectRoot = Resolve-Path (Split-Path $ProjectPath -Parent)

    $oldpaths = $env:PSModulePath

    $ModulePathSplitter = ":"
    if($IsWindows -or ($PSVersionTable.PSVersion -lt [System.Version]"6.0")) {
        $ModulePathSplitter = ";"
    }

    $env:PSModulePath = @(
        (Join-Path $ProjectRoot "Dependencies"),
        (Join-Path $ProjectRoot "src\Dependencies")
    ) -join $ModulePathSplitter

    $dependencyPaths = (Join-Path $ProjectRoot "Dependencies")

    foreach ($dependencyPath in $dependencyPaths) {
        if (-not (Test-Path $dependencyPath -PathType Container)) {
            New-Item $dependencyPath -Force -ItemType Directory | Out-Null
        }
    }

    if (![io.path]::IsPathRooted($BuildOutput)) {
        $BuildOutput = Join-Path -Path $ProjectRoot -ChildPath (Join-Path $BuildOutput $ProjectName)
    }

    New-Item $BuildOutput -Force -ItemType Directory | Out-Null

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

        Write-Verbose "BootStrapping PSDepend"
        "Parameter $BuildOutput" | Write-Verbose
        $savePSDependParams = @{
            Name = 'PSDepend', 'PowershellGet', 'Configuration'
            Path = "$ProjectRoot\Dependencies"
        }
        if ($PSBoundParameters.ContainsKey('verbose')) { $savePSDependParams.add('verbose', $verbose) }
        if ($GalleryRepository) { $savePSDependParams.Add('Repository', $GalleryRepository) }
        if ($GalleryProxy) { $savePSDependParams.Add('Proxy', $GalleryProxy) }
        if ($GalleryCredential) { $savePSDependParams.Add('ProxyCredential', $GalleryCredential) }
        Save-Module @savePSDependParams

        $DependencyInputObject = Import-PowerShellDataFile (Join-Path $ProjectRoot "PSDepend.build.psd1")

        if ($null -ne $env:SYSTEM_ACCESSTOKEN) {
            $DependencyInputObject.BR.Name = $DependencyInputObject.BR.Name.Replace("https://", "https://$env:BuildServiceAccountId:$env:SYSTEM_ACCESSTOKEN`@")
        }

        Export-Metadata -InputObject $DependencyInputObject -Path (Join-Path $ProjectRoot "PSDepend.build.psd1") -AsHashtable

        $PSDependParams = @{
            Force       = $true
            Path        = (Join-Path $ProjectRoot "PSDepend.build.psd1")
            Install     = $true
            Target      = "$ProjectRoot\Dependencies"
        }

        ##### HACK for psdepend #####
        $map = Get-Item "$ProjectRoot\Dependencies\PSDepend\*\PSDependMap.psd1"
        $newmap = (Get-Content $map) -replace "Supports = 'windows'$", "Supports = 'windows', 'core', 'linux', 'macos'"
        Set-Content -path $map -Value $newmap -Force
        #############################

        $null = Invoke-PSDepend @PSDependParams >> $null
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
        $PSBoundParameters["ProjectName"] = $ProjectName
        $PSBoundParameters["ProjectPath"] = $ProjectPath
        $PSBoundParameters["BuildOutput"] = $BuildOutput

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

    $buildFiles = Get-Item $ProjectRoot\.build\* -Include *.ps1
    foreach ($buildFile in $buildFiles) {
        "Importing file $($buildFile.BaseName)" | Write-Verbose
        . $buildFile.FullName
    }
}

end {
    $env:PSModulePath = $oldpaths
}
