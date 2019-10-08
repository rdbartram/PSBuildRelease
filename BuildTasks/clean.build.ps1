Param (

    [io.DirectoryInfo]
    $ProjectPath = (property ProjectPath $BuildRoot),

    [parameter()]
    [string]
    $ProjectName = (property ProjectName $ProjectName),

    [string]
    $BuildOutput = (property BuildOutput 'C:\BuildOutput'),

    [string]
    $LineSeparation = (property LineSeparation ('-' * 78))
)

task Clean {
    $LineSeparation
    "`t CLEAN UP"
    $LineSeparation

    Get-ChildItem $BuildOutput -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -Verbose -ErrorAction Stop
}

task CleanPackage -before PackageModule {
    Get-ChildItem -Path $BuildOutput -Filter ('{0}_*.zip' -f $ProjectName) -ErrorAction SilentlyContinue | Remove-Item  -Force -ErrorAction SilentlyContinue
}
