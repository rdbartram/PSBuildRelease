Param (
    [parameter()]
    [io.DirectoryInfo]
    $ProjectPath = (property ProjectPath $BuildRoot)
)

task incrementscriptversion -Inputs (Get-ChildItem -Path $ProjectPath\* -Include "*.ps1") {

    Write-Host ("Updating Runbook revision to '{0}' ..." -f $env:GITVERSION_MajorMinorPatch)
    $Inputs | ForEach-Object -Process {
        Update-ScriptFileInfo -Path $_ -Version $env:GITVERSION_MajorMinorPatch
    }
}

task DownloadRunbookDependentModules -Inputs (Get-ChildItem -Path $ProjectPath\* -Include "*.ps1") -Outputs (Join-Path $ProjectPath Dependencies\module.txt) {

    New-Item -Path (Join-Path $ProjectPath Dependencies) -ItemType Directory -Force | Out-Null

    $Modules = @()
    $Inputs.Foreach{
        $Manifest = Test-ScriptFileInfo $_

        $Modules += $Manifest.RequiredModules
    }

    $Modules | Select-Object -Unique | Where-Object { $null -ne $_ } | ForEach-Object -Process {
        Find-Module $_ | Sort-Object Version -Descending | Select-Object -First 1 | ForEach-Object {
            if ([System.Management.Automation.SemanticVersion](Get-Module $_.Name -listavailable).Version -lt [System.Management.Automation.SemanticVersion]$_.version) {
                Save-Module $_.Name -path (Join-Path $ProjectPath Dependencies) -Repository $_.Repository
            }
        }
    }

    New-Item -Path $outputs -ItemType File -Force | Out-Null
}
