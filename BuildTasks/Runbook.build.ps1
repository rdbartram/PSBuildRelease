Param (
    [parameter()]
    [io.DirectoryInfo]
    $ProjectPath = (property ProjectPath $BuildRoot)
)

task IncrementScriptVersion -Inputs (Get-ChildItem -Path $ProjectPath\* -Include "*.ps1") {

    Write-Host ("Updating Runbook revision to '{0}' ..." -f $env:GITVERSION_MajorMinorPatch)

    foreach ($inputArg in $Inputs) {
        Update-ScriptFileInfo -Path $inputArg -Version $env:GITVERSION_MajorMinorPatch
    }
}

task DownloadRunbookDependentModules -Inputs (Get-ChildItem -Path $ProjectPath\* -Include "*.ps1") -Outputs (Join-Path $ProjectPath Dependencies\module.txt) {

    New-Item -Path (Join-Path $ProjectPath Dependencies) -ItemType Directory -Force | Out-Null

    $modules = @()
    foreach ($inputArg in $Inputs) {
        $manifest = Test-ScriptFileInfo $inputArg

        $modules += $manifest.Requiredmodules
    }

    $uniqueModules = $modules | Select-Object -Unique | Where-Object { $null -ne $_ }
    foreach ($uniqueModule in $uniqueModules) {
        $availableModule = Find-Module $uniqueModule | Sort-Object Version -Descending | Select-Object -First 1

        if ([System.Management.Automation.SemanticVersion](Get-Module $availableModule.Name -listavailable).Version -lt [System.Management.Automation.SemanticVersion]$availableModule.version) {
            Save-Module $availableModule.Name -path (Join-Path $ProjectPath Dependencies) -Repository $availableModule.Repository
        }
    }

    New-Item -Path $outputs -ItemType File -Force | Out-Null
}
