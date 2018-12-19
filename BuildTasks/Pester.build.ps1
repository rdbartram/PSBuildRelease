param (
    [parameter()]
    [io.DirectoryInfo]
    $ProjectPath = (property ProjectPath $BuildRoot))

task Test {
    $PathsToCover = @()
    "$ProjectPath\Classes\*.ps1", "$ProjectPath\Private\*.ps1", "$ProjectPath\Public\*.ps1" | % {
        if (Test-Path $_) {
            $PathsToCover += $_
        }
    }

    $pesterArgs = @{
        PassThru     = $true
        ExcludeTag   = 'alpha'
        CodeCoverage = $PathsToCover
    }

    [void] $pesterArgs.Add('OutputFormat', 'NUnitXml')
    [void] $pesterArgs.Add('OutputFile', "$ProjectPath\TEST-Results.xml")

    [void] $pesterArgs.Add('CodeCoverageOutputFileFormat', 'JaCoCo')
    [void] $pesterArgs.Add('CodeCoverageOutputFile', "$ProjectPath\Coverage.xml")

    $result = Invoke-Pester @pesterArgs
    if ($result.FailedCount -gt 0) {
        Write-Error -Message 'One or more tests failed!'
    }
}
