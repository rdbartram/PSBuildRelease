param (
    [parameter()]
    [io.DirectoryInfo]
    $ProjectPath = (property ProjectPath $BuildRoot),

    [parameter()]
    [string]
    $ProjectName = (property ProjectName $ProjectName),

    [string]
    $BuildOutput = (property BuildOutput 'C:\BuildOutput'),

    [string]
    $PublishGallery = (property PublishGallery "psgallery"),

    [string]
    $PublishKey = (property PublishKey $PublishKey)
)

task PublishToGallery {
    $Manifest = Join-Path $BuildOutput "$ProjectName.psd1"
    $ManifestData = Import-PowerShellDataFile $Manifest
    Write-Verbose "Publishing version [$($ManifestData.ModuleVersion)] to repository [$PublishGallery]..."

    $publishParams = @{
        Path       = $BuildOutput
        Repository = $PublishGallery
        Verbose    = $VerbosePreference
    }

    if ($null -ne $PublishKey) {
        $publishParams.NuGetApiKey = $PublishKey
    }

    Publish-Module @publishParams
}
