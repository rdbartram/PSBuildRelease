#Requires -Modules Microsoft.PowerShell.Security
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
    $Cert,

    [parameter()]
    [switch]
    $CounterSign,

    [Parameter()]
    [Uri]
    $TimestampServer = 'http://timestamp.globalsign.com/scripts/timstamp.dll'
)

task UpdateSignature {

    if($true -eq $IsWindows -and $null -eq $cert) {
        $Cert = (Select-Object -First 1 -InputObject (Get-ChildItem -Path cert:\CurrentUser\my -CodeSigningCert))
    }
    $powerShellFiles = Get-ChildItem $BuildOutput -Include *.psm1, *.ps1, *.psd1
    foreach ($powerShellFile in $powerShellFiles) {
        if ($CounterSign.IsPresent) {
            Set-AuthenticodeSignature $powerShellFile -Certificate $Cert -TimestampServer $TimestampServer -Confirm:$false
        } else {
            Set-AuthenticodeSignature $powerShellFile -Certificate $Cert -Confirm:$false
        }
    }
}

task CreateNugetSpec -Inputs ("$BuildOutput\$ProjectName.psd1") -Outputs ("$BuildOutput\$ProjectName.nuspec") {
    $moduleData = Import-PowerShellDataFile $Inputs

    [xml]$doc = New-Object System.Xml.XmlDocument

    $dec = $doc.CreateXmlDeclaration("1.0", "UTF-8", $null)
    $null = $doc.AppendChild($dec)

    $ns = "http://schemas.microsoft.com/packaging/2011/08/nuspec.xsd"

    $packageElement = $doc.CreateNode("element", "package", $ns)

    # metadata
    $metaDataElement = $doc.CreateNode("element", "metadata", $ns)

    $idElement = $doc.CreateNode("element", "id", $ns)
    $idElement.InnerText = $ProjectName
    $null = $metaDataElement.AppendChild($idElement)

    $versionElement = $doc.CreateNode("element", "version", $ns)
    $versionElement.InnerText = $moduleData.ModuleVersion + $ModulesData.PrivateData.PSData.Prerelease
    $null = $metaDataElement.AppendChild($versionElement)

    $titleElement = $doc.CreateNode("element", "title", $ns)
    $titleElement.InnerText = $ProjectName
    $null = $metaDataElement.AppendChild($titleElement)

    $authorsElement = $doc.CreateNode("element", "authors", $ns)
    $authorsElement.InnerText = $moduleData.Author
    $null = $metaDataElement.AppendChild($authors)

    $ownersElement = $doc.CreateNode("element", "owners", $ns)
    $ownersElement.InnerText = $moduleData.Author
    $null = $metaDataElement.AppendChild($ownersElement)

    $projectURLElement = $doc.CreateNode("element", "projectUrl", $ns)
    $projectURLElement.InnerText = $moduleData.PrivateData.PSData.ProjectUri
    $null = $metaDataElement.AppendChild($projectURLElement)

    $requireLicenseAcceptanceElement = $doc.CreateNode("element", "requireLicenseAcceptance", $ns)
    $requireLicenseAcceptanceElement.InnerText = $false.ToString().ToLower()
    $null = $metaDataElement.AppendChild($requireLicenseAcceptanceElement)

    $descriptionElement = $doc.CreateNode("element", "description", $ns)
    $descriptionElement.InnerText = $moduleData.description
    $null = $metaDataElement.AppendChild($descriptionElement)

    $summaryElement = $doc.CreateNode("element", "summary", $ns)
    $summaryElement.InnerText = $moduleData.Description
    $null = $metaDataElement.AppendChild($summaryElement)

    $tagsElement = $doc.CreateNode("element", "tags", $ns)
    $tagsElement.InnerText = $moduleData.PrivateData.PSData.Tags
    $null = $metaDataElement.AppendChild($tagsElement)

    $languageElement = $doc.CreateNode("element", "language", $ns)
    $languageElement.InnerText = "en-US"
    $null = $metaDataElement.AppendChild($languageElement)

    $null = $packageElement.AppendChild($metaDataElement)

    $filelistElement = $doc.CreateNode("element", "files", $ns)

    foreach ($file in $moduleData.FileList) {
        $fileElement = $doc.CreateNode("element", "file", $ns)
        $xmlSrc = $doc.CreateAttribute('src')
        $xmlSrc.Value = (Join-Path $BuildOutput $file)
        $xmlTarget = $doc.CreateAttribute('target')
        $xmlTarget.Value = $file
        $null = $fileElement.Attributes.Append($xmlSrc)
        $null = $fileElement.Attributes.Append($xmlTarget)
        $null = $filelistElement.AppendChild($fileElement)
    }

    $null = $packageElement.AppendChild($filelistElement)
    $null = $doc.AppendChild($packageElement)

    $doc.Save($outputs)
}
