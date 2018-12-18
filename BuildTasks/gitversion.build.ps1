task gitversion {
    $GitVersionInfo = GitVersion | ConvertFrom-Json
    $env:GITVERSION_SEMVER = $GitVersionInfo.SemVer
    $env:GITVERSION_ASSEMBLYSEMVER = $GitVersionInfo.AssemblySemVer
}

task fakegitversion {
    Write-Warning 'gitversion was not found. The supplied version is a default and not necessarily useful'
    $env:GITVERSION_SEMVER = "1.0.0-local.1"
    $env:GITVERSION_ASSEMBLYSEMVER = "1.0.0.0"
}
