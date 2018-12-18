task gitversion -before CreateModuleManifest, IncrementScriptVersion -If ((get-command gitversion -ErrorAction SilentlyContinue) -and -not $env:SYSTEM_ACCESSTOKEN) {
    $GitVersionInfo = GitVersion | ConvertFrom-Json
    $env:GITVERSION_SEMVER = $GitVersionInfo.SemVer
    $env:GITVERSION_ASSEMBLYSEMVER = $GitVersionInfo.AssemblySemVer
}

task fakegitversion -before CreateModuleManifest, IncrementScriptVersion -If (-not (get-command gitversion -ErrorAction SilentlyContinue) -and -not $env:SYSTEM_ACCESSTOKEN) {
    Write-Warning 'gitversion was not found. The supplied version is a default and not necessarily useful'
    $env:GITVERSION_SEMVER = "1.0.0-local.1"
    $env:GITVERSION_ASSEMBLYSEMVER = "1.0.0.0"
}
