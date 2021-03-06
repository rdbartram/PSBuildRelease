param (
    [parameter()]
    [io.DirectoryInfo]
    $ProjectPath = (property ProjectPath $BuildRoot),

    [parameter()]
    [string]
    $ProjectName = (property ProjectName $ProjectName),

    [string]
    $BuildOutput = (property BuildOutput 'C:\BuildOutput')
)

task BuildModule @{
    before  = @("CreateModuleManifest")
    inputs  = {
        Get-ChildItem (Join-Path $ProjectPath "public"), (Join-Path $ProjectPath "classes"), (Join-Path $ProjectPath "private") -Recurse -Filter *.ps1 -ErrorAction SilentlyContinue
    }
    outputs = { Join-Path $BuildOutput "$ProjectName.psm1"
    }
    Jobs    = 'CompileClasses', {
        $moduleFile = Join-Path $BuildOutput "$ProjectName.psm1"

        New-Item $moduleFile -Force | Out-Null

        if ($null -ne (Get-ChildItem (Join-Path $ProjectPath "classes") -Recurse -Filter *.psm1 -ErrorAction SilentlyContinue)) {
            Add-Content -Path $moduleFile -Value "using module .\$ProjectName-Classes.psm1" -Force
        }

        $usings = @()
        $functionFiles = Get-ChildItem (Join-Path $ProjectPath "public"), (Join-Path $ProjectPath "private") -Recurse -Filter *.ps1 -ErrorAction SilentlyContinue

        foreach ($functionFile in $functionFiles) {
            $path = $functionFile.FullName
            $usingRaws = (Get-Content $functionFile.FullName) -match '^using ((module)|(namespace))'

            foreach ($usingRaw in $usingRaws) {
                if ($usings -contains $usingRaw) {
                } elseif ($usingRaw -match '^using module [^.]') {
                    Add-Content -Path $moduleFile -Value $usingRaw -Force
                } elseif (
                    $usingRaw -match '^using module (\.{0,2}\\.*binaries)\\(.+)' -and
                    (Resolve-Path (Join-Path $ProjectPath "binaries")).ToString() -eq (Resolve-Path (Join-Path (Split-Path $path -Parent) $matches[1]).ToString())
                ) {
                    Add-Content -Path $moduleFile -Value "using module .\binaries\$($matches[2])" -Force
                } elseif ($usingRaw -match '^using namespace') {
                    Add-Content -Path $moduleFile -Value $usingRaw -Force
                }
                $usings += $usingRaw
            }
        }

        if (Test-Path (Join-Path $ProjectPath "Strings\Strings.psd1")) {
            Add-Content -Path $moduleFile -Value 'Import-LocalizedData -BaseDirectory (Join-Path $PSScriptRoot "strings") -BindingVariable Strings -FileName "strings.psd1"' -Force
        }

        foreach ($functionFile in $functionFiles) {
            Add-Content -Path $moduleFile -Value ((Get-Content $functionFile.FullName) -notmatch '^using ((module)|(namespace))') -Force
        }

        $publicFunctions = @()
        $publicFiles = Get-ChildItem (Join-Path $ProjectPath "public") -Exclude "_root.ps1" -Recurse -Filter *.ps1 -ErrorAction SilentlyContinue

        foreach ($publicFile in $publicFiles) {
            $publicFunctions += $publicFile.BaseName
        }

        Add-Content -Path $moduleFile -Value ("Export-ModuleMember -Function {0}" -f ($publicFunctions -join ",$([System.Environment]::newline)")) -Force
    }
}

task CopyStaticResources @{
    before = "CreateModuleManifest"
    if     = {
        $manifest = Get-Content (Join-Path $BuildRoot "Manifest.json") -ea SilentlyContinue | ConvertFrom-Json
        $null -ne $manifest.StaticResources
    }
    Jobs   = {
        $manifest = Get-Content (Join-Path $BuildRoot "Manifest.json") -ea SilentlyContinue | ConvertFrom-Json
        foreach ($r in $manifest.StaticResources) {
            Copy-Item (Join-Path $ProjectPath $r) $BuildOutput -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

task CreateModuleManifest -before PackageModule, CreateNugetSpec, DownloadDependentModules, CompileScriptToExe -inputs (Join-Path $BuildOutput "$ProjectName.psm1") -outputs (Join-Path $BuildOutput "$ProjectName.psd1") {
    $moduleFile = $inputs
    $moduleManifest = Join-Path $BuildOutput "$ProjectName.psd1"

    New-Item $moduleManifest -Force | Out-Null

    $publicFunctions = @()
    $publicFiles = Get-ChildItem (Join-Path $ProjectPath "public")

    foreach ($publicFile in $publicFiles) {
        $publicFunctions += $publicFile.BaseName
    }

    $requiredModules = @()
    $moduleRequirements = (Get-Content $moduleFile) -match '^#requires'

    foreach ($moduleRequirement in $moduleRequirements) {
        if ($moduleRequirement -match '-module (.+)') {
            $requiredModules += $matches[1].split(",").trim().ToLower()
        }
    }

    $manifestData = @{
        Path              = $moduleManifest
        RootModule        = "$ProjectName.psm1"
        RequiredModules   = ($requiredModules | Sort-Object | Select-Object -Unique)
        FunctionsToExport = $publicFunctions
        ModuleVersion     = $env:GITVERSION_MAJORMINORPATCH
        FileList          = (Get-ChildItem $BuildOutput -Recurse -File | ForEach-Object -Process { ($_.FullName -Replace "$([regex]::Escape($BuildOutput))") -Replace '^\\|\/' }) | Select-Object -Unique
    }

    if ($ProjectUri = (git remote get-url origin)) {
        $manifestData["ProjectUri"] = $projectUri
    }

    $manifestJson = Get-Content (Join-Path $BuildRoot Manifest.json) | ConvertFrom-Json

    ##### hack to remove unsupported params
    $cmdParams = Get-Command New-ModuleManifest | Select-Object -ExpandProperty parameters

    foreach ($manifestProperty in $manifestJson.ModuleInfo.PSObject.Properties.where{ $cmdParams.ContainsKey($_.name) }) {
        $manifestData[$manifestProperty.Name] = $manifestProperty.Value
    }
    #####

    $manifestData.remove("Name") | Out-Null

    New-ModuleManifest @manifestData -ErrorAction stop

    #####prerelease hack until powershell supports native

    if ($false -eq [string]::IsNullOrEmpty($env:GITVERSION_NUGETPRERELEASETAGV2)) {
        $moduleData = ConvertFrom-Metadata $moduleManifest
        $moduleData.PrivateData.PSData += @{ prerelease = "-$env:GITVERSION_NUGETPRERELEASETAGV2" }
        Export-Metadata -Path $moduleManifest -InputObject $moduleData
    }

    #####
}

Task PackageModule -inputs { Get-ChildItem $BuildOutput -Recurse -Exclude *.zip, *.nuspec -File } -Outputs (Join-Path -Path $BuildOutput -ChildPath ('{0}_{1}.zip' -f $ProjectName, $env:GITVERSION_NUGETVERSIONV2)) {
    Compress-Archive -Path (Join-Path $BuildOutput "*") -DestinationPath $Outputs -Force
}

Task DownloadDependentModules -before CompileScriptToExe -Inputs (Join-Path $BuildOutput "$ProjectName.psd1") -Outputs (Join-Path $ProjectPath Dependencies\module.txt) {

    $requiredModules = (Import-PowerShellDataFile $inputs).RequiredModules

    if ($requiredModules.count -gt 0) {
        $uniqueModules = $requiredModules | Select-Object -Unique | Where-Object { $null -ne $_ }
        New-Item -Path (Join-Path $ProjectPath Dependencies) -ItemType Directory -Force | Out-Null
        foreach ($uniqueModule in $uniqueModules) {
            # Find module in PSGallery and create version object from string version
            $foundModule = Find-Module $uniqueModule -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
            $foundVersion = $null
            if ($null -eq $foundModule) {
                Write-Warning "$uniqueModule was not found"
                continue
            }

            if (-not [System.Management.Automation.SemanticVersion]::TryParse($foundModule.Version, [ref]$foundVersion)) {
                [System.Version]::TryParse($foundModule.Version, [ref]$foundVersion) | Out-Null
            }

            # Find locally installed module and create version object from string version
            $availableVersionString = $availableVersion = (Get-Module $foundModule.Name -ListAvailable).Version
            if (-not [System.Management.Automation.SemanticVersion]::TryParse($availableVersionString, [ref]$availableVersion)) {
                [System.Version]::TryParse($availableVersionString, [ref]$availableVersion) | Out-Null
            }

            # if've there is a newer version available, then download it
            if ($availableVersion -lt $FoundVersion) {
                Save-Module $foundModule.Name -path (Join-Path $ProjectPath Dependencies) -Repository $foundModule.Repository -AcceptLicense
            }
        }
    }

    New-Item -Path $outputs -ItemType File -Force | Out-Null
}

task CompileScriptToExe -inputs (Join-Path $BuildOutput "$ProjectName.ps1"), (Join-Path $BuildRoot package.psd1) -outputs (Join-Path $BuildOutput "$ProjectName.exe") {
    Merge-Script -ConfigFile $inputs[1] -Verbose
}