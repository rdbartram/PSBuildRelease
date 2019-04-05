task GitVersion -before CreateModuleManifest, IncrementScriptVersion -If ((get-command gitversion -ErrorAction SilentlyContinue) -and -not $env:SYSTEM_ACCESSTOKEN) {
    $gitVersionInfo = GitVersion | ConvertFrom-Json
    $env:GITVERSION_MajorMinorPatch = $gitVersionInfo.MajorMinorPatch
    $env:GITVERSION_NuGetPreReleaseTagV2 = $gitVersionInfo.NuGetPreReleaseTagV2
    $env:GITVERSION_NuGetVersionV2 = $gitVersionInfo.NuGetVersionV2
}

task FakeGitVersion -before CreateModuleManifest, IncrementScriptVersion -If (-not (get-command gitversion -ErrorAction SilentlyContinue) -and -not $env:SYSTEM_ACCESSTOKEN) {
    Write-Warning 'gitversion was not found. The supplied version is a default and not necessarily useful'
    $env:GITVERSION_MajorMinorPatch = "1.0.0"
    $env:GITVERSION_NuGetPreReleaseTagV2 = ""
    $env:GITVERSION_NuGetVersionV2 = "1.0.0"
}
