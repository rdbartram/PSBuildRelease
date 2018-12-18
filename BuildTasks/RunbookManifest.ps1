Param (
    [parameter()]
    [io.DirectoryInfo]
    $ProjectPath = (property ProjectPath $BuildRoot)
)

task incrementscriptversion -Inputs  {
    $Runbooks = Get-ChildItem -Path $ProjectPath\Runbooks\* -Include "*.ps1"

    Write-Host ("Updating Runbook revision to '{0}' ..." -f $env:GITVERSION_ASSEMBLYSEMVER)
    Get-ChildItem -Path $ProjectPath\Runbooks\* -Include "*.ps1" -PipelineVariable RunbookScriptFile | ForEach-Object -Process {
        Update-ScriptFileInfo -Path $RunbookScriptFile.FullName -Version $env:GITVERSION_ASSEMBLYSEMVER
    }
}
