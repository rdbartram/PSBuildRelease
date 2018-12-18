param (
    [parameter()]
    [io.DirectoryInfo]
    $ProjectPath = (property ProjectPath $BuildRoot),

    [parameter()]
    [string]
    $ProjectName = (property ProjectName $ProjectName),

    [parameter()]
    [switch]
    $Pack,

    [parameter()]
    $Cert = (Select-Object -First 1 -InputObject (Get-ChildItem -Path cert:\CurrentUser\my -CodeSigningCert)),

    [parameter()]
    [switch]
    $CounterSign,

    [Parameter()]
    [Uri]
    $TimestampServer = 'http://timestamp.globalsign.com/scripts/timstamp.dll'
)

task Test {
    $PathsToCover = @()
    "$ProjectPath\src\Classes\*.ps1", "$ProjectPath\src\Private\*.ps1", "$ProjectPath\src\Public\*.ps1" | % {
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
