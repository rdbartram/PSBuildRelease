task gitversion -before CreateModuleManifest, IncrementScriptVersion -If ((get-command gitversion -ErrorAction SilentlyContinue) -and -not $env:SYSTEM_ACCESSTOKEN) {
    $GitVersionInfo = GitVersion | ConvertFrom-Json
    $env:GITVERSION_MajorMinorPatch = $GitVersionInfo.MajorMinorPatch
    $env:GITVERSION_NuGetPreReleaseTagV2 = $GitVersionInfo.NuGetPreReleaseTagV2
    $env:GITVERSION_NuGetVersionV2 = $GitVersionInfo.NuGetVersionV2
}

task fakegitversion -before CreateModuleManifest, IncrementScriptVersion -If (-not (get-command gitversion -ErrorAction SilentlyContinue) -and -not $env:SYSTEM_ACCESSTOKEN) {
    Write-Warning 'gitversion was not found. The supplied version is a default and not necessarily useful'
    $env:GITVERSION_MajorMinorPatch = "1.0.0"
    $env:GITVERSION_NuGetPreReleaseTagV2 = "dev1"
    $env:GITVERSION_NuGetVersionV2 = "1.0.0-dev1"
}
