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
        Get-Item $ProjectPath\public\*, $ProjectPath\classes\*, $ProjectPath\private\* -ErrorAction SilentlyContinue
    }
    outputs = { "$BuildOutput\$ProjectName.psm1"
    }
    Jobs    = 'CompileClasses', {
        $moduleFile = Join-Path $BuildOutput "$ProjectName.psm1"

        New-Item $moduleFile -Force | Out-Null

        if ($null -ne (Get-Item $ProjectPath\classes\* -ErrorAction SilentlyContinue)) {
            Add-Content -Path $moduleFile -Value "using module .\$ProjectName-Classes.psm1" -Force
        }

        $usings = @()
        $functionFiles = Get-ChildItem $ProjectPath\Private, $ProjectPath\Public -ErrorAction SilentlyContinue

        foreach ($functionFile in $functionFiles) {
            $path = $functionFile.FullName
            $usingRaws = (Get-Content $functionFile.FullName) -match 'using (module)|(namespace)'

            foreach ($usingRaw in $usingRaws) {
                if ($usings -contains $usingRaw) {
                } elseif ($usingRaw -match 'using module [^.]') {
                    Add-Content -Path $moduleFile -Value $usingRaw -Force
                } elseif (
                    $usingRaw -match 'using module (\.{0,2}\\.*binaries)\\(.+)' -and
                    (Resolve-Path (Join-Path $ProjectPath "Binaries")).ToString() -eq (Resolve-Path (Join-Path (Split-Path $path -Parent) $matches[1]).ToString())
                ) {
                    Add-Content -Path $moduleFile -Value "using module .\Binaries\$($matches[2])" -Force
                } elseif ($usingRaw -match 'using namespace') {
                    Add-Content -Path $moduleFile -Value $usingRaw -Force
                }
                $usings += $usingRaw
            }
        }

        if (Test-Path $ProjectPath\Strings\Strings.psd1) {
            Add-Content -Path $moduleFile -Value 'Import-LocalizedData -BaseDirectory "$PSScriptRoot\Strings" -BindingVariable Strings -FileName "strings.psd1"' -Force
        }

        foreach ($functionFile in $functionFiles) {
            Add-Content -Path $moduleFile -Value ((Get-Content $functionFile.FullName) -notmatch 'using (module)|(namespace)') -Force
        }

        $publicFunctions = @()
        $publicFiles = Get-ChildItem $ProjectPath\Public\ -Exclude "_root.ps1"

        foreach ($publicFile in $publicFiles) {
            $publicFunctions += $publicFile.BaseName
        }

        Add-Content -Path $moduleFile -Value ("Export-ModuleMember -Function {0}" -f ($publicFunctions -join ",$([System.Environment]::newline)")) -Force
    }
}

task CopyStaticResources @{
    before = "CreateModuleManifest"
    if     = {
        $manifest = Get-Content "$BuildRoot\Manifest.json" -ea SilentlyContinue | ConvertFrom-Json
        $null -ne $manifest.StaticResources
    }
    Jobs   = {
        $manifest = Get-Content "$BuildRoot\Manifest.json" -ea SilentlyContinue | ConvertFrom-Json
        foreach ($r in $manifest.StaticResources) {
            Copy-Item (Join-Path $ProjectPath "$r") $BuildOutput -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

task CreateModuleManifest -before PackageModule, CreateNugetSpec, DownloadDependentModules -inputs ("$BuildOutput\$ProjectName.psm1") -outputs ("$BuildOutput\$ProjectName.psd1") {
    $moduleFile = $inputs
    $moduleManifest = Join-Path $BuildOutput "$ProjectName.psd1"

    New-Item $moduleManifest -Force | Out-Null

    $publicFunctions = @()
    $publicFiles = Get-ChildItem $ProjectPath\Public\

    foreach ($publicFile in $publicFiles) {
        $publicFunctions += $publicFile.BaseName
    }

    $requiredModules = @()
    $moduleRequirements = (Get-Content $moduleFile) -match '#requires'

    foreach ($moduleRequirement in $moduleRequirements) {
        if ($_ -match '-modules (.+)( -)?') {
            $requiredModules += $matches[1].split(",").trim().ToLower()
        }
    }

    $manifestData = @{
        Path              = $moduleManifest
        RootModule        = "$ProjectName.psm1"
        RequiredModules   = ($requiredModules | Sort-Object | Select-Object -Unique)
        FunctionsToExport = $publicFunctions
        ModuleVersion     = $env:GITVERSION_MajorMinorPatch
        FileList          = (Get-ChildItem $BuildOutput -Recurse -File | ForEach-Object -Process { $_.FullName -Replace "$([regex]::Escape($BuildOutput))\\?" }) + "$ProjectName.psd1" | Select-Object -Unique
    }

    if($ProjectUri = (git remote get-url origin)){
        $manifestData["ProjectUri"] = $projectUri
    }

    $manifestJson = Get-Content (Join-Path $BuildRoot Manifest.json) | ConvertFrom-Json

    foreach ($manifestProperty in $manifestJson.ModuleInfo.PSObject.Properties) {
        $manifestData[$manifestProperty.Name] = $manifestProperty.Value
    }

    $manifestData.remove("Name") | Out-Null

    New-ModuleManifest @manifestData -ErrorAction stop

    #####prerelease hack until powershell supports native

    if($null -ne $env:GITVERSION_NuGetPreReleaseTagV2) {
        $moduleData = ConvertFrom-Metadata $moduleManifest
        $moduleData.PrivateData.PSData += @{ prerelease = "-$env:GITVERSION_NuGetPreReleaseTagV2" }
        Export-Metadata -Path $moduleManifest -InputObject $moduleData
    }

    #####
}

Task PackageModule -inputs {Get-ChildItem $BuildOutput -Recurse -Exclude *.zip, *.nuspec -File} -Outputs (Join-Path -Path $BuildOutput -ChildPath ('{0}_{1}.zip' -f $ProjectName, $env:GITVERSION_NuGetVersionV2)) {
    Compress-Archive -Path $BuildOutput\* -DestinationPath $Outputs -Force
}

Task DownloadDependentModules -Inputs ("$BuildOutput\$ProjectName.psd1") -Outputs (Join-Path $ProjectPath Dependencies\module.txt) {

    $requiredModules = (Import-PowerShellDataFile $inputs).RequiredModules

    if ($requiredModule.count -gt 0) {
        $uniqueModules = $requiredModule | Select-Object -Unique | Where-Object { $null -ne $_ }
        New-Item -Path (Join-Path $ProjectPath Dependencies) -ItemType Directory -Force | Out-Null
        foreach ($uniqueModule in $uniqueModules) {
            $availableModule = Find-Module $uniqueModule | Sort-Object Version -Descending | Select-Object -First 1

            if ([System.Management.Automation.SemanticVersion](Get-Module $availableModule.Name -listavailable).Version -lt [System.Management.Automation.SemanticVersion]$availableModule.version) {
                Save-Module $availableModule.Name -path (Join-Path $ProjectPath Dependencies) -Repository $availableModule.Repository
            }
        }
    }

    New-Item -Path $outputs -ItemType File -Force | Out-Null
}
