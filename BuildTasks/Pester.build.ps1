param (
    [parameter()]
    [io.DirectoryInfo]
    $ProjectPath = (property ProjectPath $BuildRoot),

    [parameter()]
    [string[]]
    $ExcludedTag = (property ExcludedTags 'alpha')
)

task Test {
    $PathsToCover = @()
    "$ProjectPath\Classes\*.ps1", "$ProjectPath\Private\*.ps1", "$ProjectPath\Public\*.ps1" | % {
        if (Test-Path $_) {
            $PathsToCover += $_
        }
    }

    $pesterArgs = @{
        PassThru     = $true
        PesterOption = @{
            IncludeVSCodeMarker = $true
        }
        ExcludeTag   = $ExcludedTag
        CodeCoverage = $PathsToCover
    }

    if ($host.Version -gt [system.version]"6.0") {
        $pesterArgs["ExcludeTag"] += "DesktopOnly"
    } else {
        $pesterArgs["ExcludeTag"] += "CoreOnly"
    }

    [void] $pesterArgs.Add('OutputFormat', 'NUnitXml')
    [void] $pesterArgs.Add('OutputFile', "$ProjectPath\TEST-Results.xml")

    [void] $pesterArgs.Add('CodeCoverageOutputFileFormat', 'JaCoCo')
    [void] $pesterArgs.Add('CodeCoverageOutputFile', "$ProjectPath\Coverage-$($host.Version).xml")

    $result = Invoke-Pester @pesterArgs
    if ($result.FailedCount -gt 0) {
        Write-Error -Message 'One or more tests failed!'
    }
}

task RunbookTest {
    $PathsToCover = @("$ProjectPath\*.ps1")

    $pesterArgs = @{
        PassThru     = $true
        PesterOption = @{
            IncludeVSCodeMarker = $true
        }
        ExcludeTag   = @('alpha')
        CodeCoverage = $PathsToCover
    }

    if ($host.Version -gt [system.version]"6.0") {
        $pesterArgs["ExcludeTag"] += "DesktopOnly"
    } else {
        $pesterArgs["ExcludeTag"] += "CoreOnly"
    }

    [void] $pesterArgs.Add('OutputFormat', 'NUnitXml')
    [void] $pesterArgs.Add('OutputFile', "$ProjectPath\TEST-Results.xml")

    [void] $pesterArgs.Add('CodeCoverageOutputFileFormat', 'JaCoCo')
<<<<<<< HEAD
    [void] $pesterArgs.Add('CodeCoverageOutputFile', "$ProjectPath\Coverage-$($host.Version).xml")
=======
    [void] $pesterArgs.Add('CodeCoverageOutputFile', "$ProjectPath\Coverage-Results.xml")
>>>>>>> master

    $result = Invoke-Pester @pesterArgs
    if ($result.FailedCount -gt 0) {
        Write-Error -Message 'One or more tests failed!'
    }
}
