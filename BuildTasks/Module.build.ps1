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
    before  = @("CreateModuleManifest", "PackageModule")
    inputs  = {
        Get-Item $ProjectPath\public\*, $ProjectPath\classes\*, $ProjectPath\private\* -ErrorAction SilentlyContinue
    }
    outputs = { "$BuildOutput\$ProjectName.psm1"
    }
    Jobs    = 'CompileClasses', {
        $ModuleFile = Join-Path $BuildOutput "$ProjectName.psm1"

        New-Item $ModuleFile -Force | Out-Null

        if ($null -ne (Get-Item classes\* -ErrorAction SilentlyContinue)) {
            Add-Content -Path $ModuleFile -Value "using module .\$ProjectName-Classes.psm1" -Force
        }

        $usings = @()
        Get-ChildItem $ProjectPath\Private, $ProjectPath\Public | ForEach-Object -Process {
            $path = $_.FullName
            (Get-Content $_.FullName) -match 'using (module)|(namespace)' | ForEach-Object -Process {
                if ($usings -contains $_) {
                } elseif ($_ -match 'using module [^.]') {
                    Add-Content -Path $ModuleFile -Value $_ -Force
                } elseif (
                    $_ -match 'using module (\.{0,2}\\.*binaries)\\(.+)' -and
                    (Resolve-Path (Join-Path $ProjectPath "Binaries")).ToString() -eq (Resolve-Path (Join-Path (Split-Path $Path -Parent) $matches[1]).ToString())
                ) {
                    Add-Content -Path $ModuleFile -Value "using module .\Binaries\$($matches[2])" -Force
                } elseif ($_ -match 'using namespace') {
                    Add-Content -Path $ModuleFile -Value $_ -Force
                }
                $usings += $_
            }
        }

        if (Test-Path $ProjectPath\Strings\Strings.psd1) {
            Add-Content -Path $ModuleFile -Value 'Import-LocalizedData -BaseDirectory "$PSScriptRoot\Strings" -BindingVariable Strings -FileName "strings.psd1"' -Force
        }

        Get-ChildItem $ProjectPath\Private, $ProjectPath\Public | ForEach-Object -Process {
            Add-Content -Path $ModuleFile -Value ((Get-Content $_.FullName) -notmatch 'using (module)|(namespace)') -Force
        }

        $PublicFunctions = @()
        Get-ChildItem $ProjectPath\Public\ | ForEach-Object -Process {
            $PublicFunctions += $_.BaseName
        }

        Add-Content -Path $ModuleFile -Value ("Export-ModuleMember -Function {0}" -f ($PublicFunctions -join ",$([System.Environment]::newline)")) -Force
    }
}

task CopyStaticResources @{
    before = "CreateModuleManifest"
    if     = {
        $Manifest = Get-Content "$BuildRoot\Manifest.json" -ea SilentlyContinue | ConvertFrom-Json
        $null -ne $Manifest.StaticResources
    }
    Jobs   = {
        $Manifest = Get-Content "$BuildRoot\Manifest.json" -ea SilentlyContinue | ConvertFrom-Json
        foreach ($r in $Manifest.StaticResources) {
            Copy-Item (Join-Path $ProjectPath "$r\") $BuildOutput -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

task CreateModuleManifest -before PackageModule, CreateNugetSpec, DownloadDependentModules -inputs ("$BuildOutput\$ProjectName.psm1") -outputs ("$BuildOutput\$ProjectName.psd1") {
    $ModuleFile = $inputs
    $ModuleManifest = Join-Path $BuildOutput "$ProjectName.psd1"

    New-Item $ModuleManifest -Force | Out-Null

    $PublicFunctions = @()
    Get-ChildItem $ProjectPath\Public\ | ForEach-Object -Process {
        $PublicFunctions += $_.BaseName
    }

    $RequiredModules = (Get-Content $ModuleFile) -match '#requires' | ForEach-Object -Process {
        if ($_ -match '-modules (.+)( -)?') {
            $matches[1].split(",").trim().ToLower()
        }
    }

    $manifestData = @{
        Path              = $ModuleManifest
        RootModule        = "$ProjectName.psm1"
        RequiredModules   = ($RequiredModules | Sort-Object | Select-Object -Unique)
        FunctionsToExport = $PublicFunctions
        ModuleVersion     = $env:GITVERSION_ASSEMBLYSEMVER
        FileList          = (Get-ChildItem $BuildOutput -Recurse -File | ForEach-Object -Process { $_.FullName -Replace "$([regex]::Escape($BuildOutput))\\?" }) + "$ProjectName.psd1" | Select-Object -Unique
        ProjectUri        = (git remote get-url origin)
    }

    (Get-Content (Join-Path $BuildRoot Manifest.json) | ConvertFrom-Json).ModuleInfo.PSObject.Properties.Foreach{ $manifestData += @{$_.Name = $_.Value} }

    New-ModuleManifest @manifestData
}

Task PackageModule -inputs (Get-ChildItem $BuildOutput -Recurse -Exclude *.zip, *.nuspec -File) -outputs "$(Join-Path $BuildOutput "$($ProjectName)_$($env:GITVERSION_ASSEMBLYSEMVER).zip")" {
    Compress-Archive -Path (Get-ChildItem $BuildOutput -Exclude *.zip, *.nuspec) -DestinationPath $Outputs -Force
}

Task DownloadDependentModules -before Test -Inputs ("$BuildOutput\$ProjectName.psd1") -Outputs (Join-Path $ProjectPath Dependencies\) {

    $RequiredModules = (Import-PowerShellDataFile $inputs).RequiredModules | ? { $null -ne $_ } | ForEach-Object -Process {
        @{ $_ = "Latest"}
    }

    $RequiredModules += @{
        PSDependOptions = @{
            Target    = '$DependencyFolder\Dependencies'
            AddToPath = $true
        }
    }

    Invoke-PSDepend -InputObject $RequiredModules -Target (Join-Path $ProjectPath Dependencies) -Install -Confirm:$false
}
