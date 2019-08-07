task GitVersion -before CreateModuleManifest, IncrementScriptVersion -If ((get-command gitversion -ErrorAction SilentlyContinue) -and ($null -ne $env:GITVERSION_NUGETVERSIONV2)) {
    $gitVersionInfo = GitVersion | ConvertFrom-Json
    $env:GITVERSION_MAJORMINORPATCH = $gitVersionInfo.MAJORMINORPATCH
    $env:GITVERSION_NUGETPRERELEASETAGV2 = $gitVersionInfo.NUGETPRERELEASETAGV2
    $env:GITVERSION_NUGETVERSIONV2 = $gitVersionInfo.NUGETVERSIONV2
}

task FakeGitVersion -before CreateModuleManifest, IncrementScriptVersion -If (-not (get-command gitversion -ErrorAction SilentlyContinue) -and ($null -ne $env:GITVERSION_NUGETVERSIONV2)) {
    Write-Warning 'gitversion was not found. The supplied version is a default and not necessarily useful'
    $env:GITVERSION_MAJORMINORPATCH = "1.0.0"
    $env:GITVERSION_NUGETPRERELEASETAGV2 = ""
    $env:GITVERSION_NUGETVERSIONV2 = "1.0.0"
}
