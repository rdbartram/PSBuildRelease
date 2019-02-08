Param (
    [Parameter(Position = 0)]
    $Tasks,

    [Parameter()]
    [string]
    $ProjectName = "StoragePre2K12",

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
    if (![io.path]::IsPathRooted($BuildOutput)) {
        $BuildOutput = Join-Path -Path $PSScriptRoot -ChildPath $BuildOutput
    }

    function Resolve-Dependency {
        [CmdletBinding()]
        param()

        if (!($NoNuget.IsPresent) -and !(Get-PackageProvider -Name NuGet -ForceBootstrap)) {
            $providerBootstrapParams = @{
                Name           = 'nuget'
                force          = $true
                ForceBootstrap = $true
            }
            if ($PSBoundParameters.ContainsKey('verbose')) { $providerBootstrapParams.add('verbose', $verbose)}
            if ($GalleryProxy) { $providerBootstrapParams.Add('Proxy', $GalleryProxy) }
            $null = Install-PackageProvider @providerBootstrapParams
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        }

        if (!(Get-Module -ListAvailable PSDepend)) {
            Write-verbose "BootStrapping PSDepend"
            "Parameter $BuildOutput"| Write-verbose
            $InstallPSDependParams = @{
                Name         = 'PSDepend'
                AllowClobber = $true
                Confirm      = $false
                Force        = $true
                Scope        = 'CurrentUser'
            }
            if ($PSBoundParameters.ContainsKey('verbose')) { $InstallPSDependParams.add('verbose', $verbose)}
            if ($GalleryRepository) { $InstallPSDependParams.Add('Repository', $GalleryRepository) }
            if ($GalleryProxy) { $InstallPSDependParams.Add('Proxy', $GalleryProxy) }
            if ($GalleryCredential) { $InstallPSDependParams.Add('ProxyCredential', $GalleryCredential) }
            Install-Module @InstallPSDependParams
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
        $map = join-path (module psdepend -Listavailable).ModuleBase "psdependmap.psd1"
        $newmap = (gc $map) -replace "Supports = 'windows'$", "Supports = 'windows', 'core'"
        Set-content -path $map -Value $newmap -Force
        #############################

        $null = Invoke-PSDepend @PSDependParams
        Write-Verbose "Project Bootstrapped, returning to Invoke-Build"
    }

    if ($ResolveDependency) {
        Write-Host "Resolving Dependencies... [this can take a moment]"
        $Params = @{}
        if ($PSboundParameters.ContainsKey('verbose')) {
            $Params.Add('verbose', $verbose)
        }
        Resolve-Dependency @Params
    }
}

process {
    if ($MyInvocation.ScriptName -notlike '*Invoke-Build.ps1') {
        $PSBoundParameters.Remove("ResolveDependency")
        Invoke-Build $Tasks $MyInvocation.MyCommand.Path @PSBoundParameters
        return
    }

    Get-Item $PSScriptRoot\.build\* -Include *.ps1 | Where-Object -FilterScript {
        $null -ne $_
    } | Foreach-Object -Process {
        "Importing file $($_.BaseName)" | Write-Verbose
        . $_.FullName
    }
}
