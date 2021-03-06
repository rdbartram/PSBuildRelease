param (
    [parameter()]
    [io.DirectoryInfo]
    $ProjectPath = (property ProjectPath $BuildRoot),

    [parameter()]
    [string[]]
    $ExcludedTag = (property ExcludedTags 'alpha')
)

task Test {
    $pathsToCover = @()
    $filters = (Join-Path $ProjectPath "Classes\*.ps1"), (Join-Path $ProjectPath "private\*.ps1"), (Join-Path $ProjectPath "public\*.ps1")

    foreach ($filter in $filters) {
        if (Test-Path (Split-Path $filter -Parent)) {
            $pathsToCover += $filter
        }
    }

    $pesterArgs = @{
        PassThru     = $true
        PesterOption = @{
            IncludeVSCodeMarker = $true
        }
        ExcludeTag   = $ExcludedTag
        CodeCoverage = $pathsToCover
    }

    if ($PSVersionTable.PSVersion -gt [system.version]"6.0") {
        $pesterArgs["ExcludeTag"] += "DesktopOnly"
    } else {
        $pesterArgs["ExcludeTag"] += "CoreOnly"
    }

    [void] $pesterArgs.Add('OutputFormat', 'NUnitXml')
    [void] $pesterArgs.Add('OutputFile', (Join-Path $ProjectPath "TEST-Results.xml"))

    [void] $pesterArgs.Add('CodeCoverageOutputFileFormat', 'JaCoCo')
    [void] $pesterArgs.Add('CodeCoverageOutputFile', (Join-Path $ProjectPath "Coverage-$($PSVersionTable.PSVersion).xml"))

    $result = Invoke-Pester @pesterArgs
    if ($result.FailedCount -gt 0) {
        Write-Error -Message 'One or more tests failed!'
    }
}

task RunbookTest {
    $pathsToCover = @("$(Join-Path $ProjectPath "*.ps1")")

    $pesterArgs = @{
        PassThru     = $true
        PesterOption = @{
            IncludeVSCodeMarker = $true
        }
        ExcludeTag   = @('alpha')
        CodeCoverage = $pathsToCover
    }

    if ($PSVersionTable.PSVersion -gt [system.version]"6.0") {
        $pesterArgs["ExcludeTag"] += "DesktopOnly"
    } else {
        $pesterArgs["ExcludeTag"] += "CoreOnly"
    }

    [void] $pesterArgs.Add('OutputFormat', 'NUnitXml')
    [void] $pesterArgs.Add('OutputFile', (Join-path $ProjectPath "TEST-Results.xml"))

    [void] $pesterArgs.Add('CodeCoverageOutputFileFormat', 'JaCoCo')
    [void] $pesterArgs.Add('CodeCoverageOutputFile', (Join-Path $ProjectPath "Coverage-$($PSVersionTable.PSVersion).xml"))

    $result = Invoke-Pester @pesterArgs
    if ($result.FailedCount -gt 0) {
        Write-Error -Message 'One or more tests failed!'
    }
}
