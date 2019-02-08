Param (
    [Parameter(Position = 0)]
    $Tasks,

    [Parameter()]
    [string]
    $ProjectName = (split-path (get-location) -leaf),

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

process {
    if ($MyInvocation.ScriptName -notlike '*Invoke-Build.ps1') {
        $PSBoundParameters.Remove("ResolveDependency") | Out-Null
        Invoke-Build $Tasks $MyInvocation.MyCommand.Path @PSBoundParameters
        return
    }

    task ResolveDependencies {
        Write-Host "Resolving Dependencies... [this can take a moment]"
        $Params = @{}
        if ($PSboundParameters.ContainsKey('verbose')) {
            $Params.Add('verbose', $verbose)
        }
        Resolve-Dependency @Params
    }

    Get-Item $PSScriptRoot\.build\* -Include *.ps1 | Where-Object -FilterScript {
        $null -ne $_
    } | Foreach-Object -Process {
        "Importing file $($_.BaseName)" | Write-Verbose
        . $_.FullName
    }
}


begin {
    Import-Module Microsoft.PowerShell.Utility
    $oldpaths = $env:PSModulePath
    $env:PSModulePath = @(
        (Join-Path $PSScriptRoot "Dependencies"),
        (Join-Path $PSScriptRoot "src\Dependencies"),
        "C:\WINDOWS\System32\WindowsPowerShell\v1.0",
        "C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules"
    ) -join ';'

    (Join-Path $PSScriptRoot "Dependencies"), (Join-Path $PSScriptRoot "src\Dependencies") | Foreach-Object {
        if(-not (test-path $_ -PathType Container)){
            New-Item $_ -Force -ItemType Directory | Out-Null
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
            if ($PSBoundParameters.ContainsKey('verbose')) { $providerBootstrapParams.add('verbose', $verbose)}
            if ($GalleryProxy) { $providerBootstrapParams.Add('Proxy', $GalleryProxy) }
            $null = Install-PackageProvider @providerBootstrapParams
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        }

        if (!(Get-Module -Listavailable PSDepend)) {
            Write-verbose "BootStrapping PSDepend"
            "Parameter $BuildOutput"| Write-verbose
            $SavePSDependParams = @{
                Name = 'PSDepend'
                Path = "$PSScriptRoot\Dependencies"
            }
            if ($PSBoundParameters.ContainsKey('verbose')) { $SavePSDependParams.add('verbose', $verbose)}
            if ($GalleryRepository) { $SavePSDependParams.Add('Repository', $GalleryRepository) }
            if ($GalleryProxy) { $SavePSDependParams.Add('Proxy', $GalleryProxy) }
            if ($GalleryCredential) { $SavePSDependParams.Add('ProxyCredential', $GalleryCredential) }
            Save-Module @SavePSDependParams
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
        $map = join-path (Get-Module psdepend -Listavailable)[0].ModuleBase "psdependmap.psd1"
        $newmap = (Get-Content $map) -replace "Supports = 'windows'$", "Supports = 'windows', 'core'"
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

end {
    $env:PSModulePath = $oldpaths
}
