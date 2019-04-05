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
    Import-Module Microsoft.PowerShell.Utility
    $oldpaths = $env:PSModulePath
    $env:PSModulePath = @(
        "C:\Program Files\PowerShell\6",
        "C:\Program Files\PowerShell\6\Modules",
        "C:\Program Files\PowerShell\6-preview",
        "C:\Program Files\PowerShell\6-preview\Modules",
        (Join-Path $PSScriptRoot "Dependencies"),
        (Join-Path $PSScriptRoot "src\Dependencies"),
        "C:\WINDOWS\System32\WindowsPowerShell\v1.0",
        "C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules"
    ) -join ';'

    $dependencyPaths = (Join-Path $PSScriptRoot "Dependencies")

    foreach ($dependencyPath in $dependencyPaths) {
        if(-not (test-path $dependencyPath -PathType Container)){
            New-Item $dependencyPath -Force -ItemType Directory | Out-Null
        }
    }

    if (![io.path]::IsPathRooted($BuildOutput)) {
        $BuildOutput = Join-Path -Path $PSScriptRoot -ChildPath $BuildOutput
    }

    function Resolve-Dependency {
        [CmdletBinding()]
        param()

        if ($NoNuget.IsPresent -eq $false -and !(Get-PackageProvider -Name NuGet -ForceBootstrap)) {
            $providerBootstrapParams = @{
                Name           = 'nuget'
                force          = $true
                ForceBootstrap = $true
            }
            if ($PSBoundParameters.ContainsKey('Verbose')) { $providerBootstrapParams.add('Verbose', $Verbose)}
            if ($GalleryProxy) { $providerBootstrapParams.Add('Proxy', $GalleryProxy) }
            $null = Install-PackageProvider @providerBootstrapParams
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        }

        if (!(Get-Module -Listavailable PSDepend)) {
            Write-Verbose "BootStrapping PSDepend"
            "Parameter $BuildOutput"| Write-Verbose
            $savePSDependParams = @{
                Name = 'PSDepend'
                Path = "$PSScriptRoot\Dependencies"
            }
            if ($PSBoundParameters.ContainsKey('Verbose')) { $savePSDependParams.add('Verbose', $Verbose)}
            if ($GalleryRepository) { $savePSDependParams.Add('Repository', $GalleryRepository) }
            if ($GalleryProxy) { $savePSDependParams.Add('Proxy', $GalleryProxy) }
            if ($GalleryCredential) { $savePSDependParams.Add('ProxyCredential', $GalleryCredential) }
            Save-Module @savePSDependParams
        }

        $dependencyInputObject = Import-PowerShellDataFile (Join-Path $PSScriptRoot "PSDepend.build.psd1")

        if ($null -ne $env:SYSTEM_ACCESSTOKEN) {
            $dependencyInputObject.BR.Name = $dependencyInputObject.BR.Name.Replace("https://", "https://$env:BuildServiceAccountId:$env:SYSTEM_ACCESSTOKEN`@")
        }

        $PSDependParams = @{
            Force       = $true
            InputObject = $dependencyInputObject
            Install     = $true
            Target      = "$PSScriptRoot\Dependencies"
        }

        ##### HACK for psdepend #####
        $map = join-path (Get-Module psdepend -Listavailable)[0].ModuleBase "psdependmap.psd1"
        $newmap = (Get-Content $map) -replace "Supports = 'windows'$", "Supports = 'windows', 'core'"
        Set-content -path $map -Value $newmap -Force
        #############################

        $null = Invoke-PSDepend @PSDependParams
        Write-Verbose "Project Bootstrapped, returning to Invoke-Build"
    }

    if ($ResolveDependency) {
        Write-Host "Resolving Dependencies... [this can take a moment]"
        $params = @{}
        if ($PSboundParameters.ContainsKey('Verbose')) {
            $params.Add('Verbose', $Verbose)
        }
        Resolve-Dependency @params
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
        $params = @{}
        if ($PSboundParameters.ContainsKey('Verbose')) {
            $params.Add('Verbose', $Verbose)
        }
        Resolve-Dependency @params
    }

    $buildFiles = Get-Item $PSScriptRoot\.build\* -Include *.ps1
    foreach ($buildFile in $buildFiles){
        "Importing file $($buildFile.BaseName)" | Write-Verbose
        . $buildFile.FullName
    }
}

end {
    $env:PSModulePath = $oldpaths
}
