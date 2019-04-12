Param (
    [parameter()]
    [io.DirectoryInfo]
    $ProjectPath = (property ProjectPath $BuildRoot)
)

task IncrementScriptVersion -Inputs (Get-ChildItem -Path $ProjectPath\* -Include "*.ps1") -Outputs (Join-Path $ProjectPath RunbookCompiled.txt) {

    Write-Host ("Updating Runbook revision to '{0}' ..." -f $env:GITVERSION_MajorMinorPatch)

    foreach ($inputArg in $Inputs) {
        Update-ScriptFileInfo -Path $inputArg -Version $env:GITVERSION_MajorMinorPatch
    }

    New-Item -Path $outputs -ItemType File -Force | Out-Null
}

task DownloadRunbookDependentModules -Inputs (Get-ChildItem -Path $ProjectPath\* -Include "*.ps1") -Outputs (Join-Path $ProjectPath Dependencies\module.txt) {

    $requiredModules = @()
    foreach ($inputArg in $Inputs) {
        $manifest = Test-ScriptFileInfo $inputArg

        $requiredModules += $manifest.Requiredmodules
    }

    if ($requiredModules.count -gt 0) {
        $uniqueModules = $requiredModules | Select-Object -Unique | Where-Object { $null -ne $_ }
        New-Item -Path (Join-Path $ProjectPath Dependencies) -ItemType Directory -Force | Out-Null
        foreach ($uniqueModule in $uniqueModules) {
            # Find module in PSGallery and create version object from string version
            $foundModule = Find-Module $uniqueModule | Sort-Object Version -Descending | Select-Object -First 1
            $foundVersion = $null
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
