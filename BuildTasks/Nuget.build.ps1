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
    $Cert = (Select-Object -First 1 -InputObject (Get-ChildItem -Path cert:\CurrentUser\my -CodeSigningCert)),

    [parameter()]
    [switch]
    $CounterSign,

    [Parameter()]
    [Uri]
    $TimestampServer = 'http://timestamp.globalsign.com/scripts/timstamp.dll'
)

task UpdateSignature {
    Get-ChildItem $BuildOutput -Include *.psm1, *.ps1, *.psd1 | ForEach-Object -Process {
        if ($CounterSign.IsPresent) {
            Set-AuthenticodeSignature $_ -Certificate $cert -TimestampServer $TimestampServer -Confirm:$false
        } else {
            Set-AuthenticodeSignature $_ -Certificate $cert -Confirm:$false
        }
    }
}

task CreateNugetSpec -Inputs ("$BuildOutput\$ProjectName.psd1") -Outputs ("$BuildOutput\$ProjectName.nuspec") {
    $ModuleData = Import-PowerShellDataFile $Inputs

    [xml]$Doc = New-Object System.Xml.XmlDocument

    $dec = $Doc.CreateXmlDeclaration("1.0", "UTF-8", $null)
    $null = $Doc.AppendChild($dec)

    $ns = "http://schemas.microsoft.com/packaging/2011/08/nuspec.xsd"

    $PackageElement = $doc.CreateNode("element", "package", $ns)

    # metadata
    $MetaDataElement = $doc.CreateNode("element", "metadata", $ns)

    $IdElement = $doc.CreateNode("element", "id", $ns)
    $IdElement.InnerText = $ProjectName
    $null = $MetaDataElement.AppendChild($IdElement)

    $VersionElement = $doc.CreateNode("element", "version", $ns)
    $VersionElement.InnerText = $ModuleData.ModuleVersion + $ModulesData.PrivateData.PSData.Prerelease
    $null = $MetaDataElement.AppendChild($VersionElement)

    $TitleElement = $doc.CreateNode("element", "title", $ns)
    $TitleElement.InnerText = $ProjectName
    $null = $MetaDataElement.AppendChild($TitleElement)

    $Authors = $doc.CreateNode("element", "authors", $ns)
    $Authors.InnerText = $ModuleData.Author
    $null = $MetaDataElement.AppendChild($Authors)

    $OwnersElement = $doc.CreateNode("element", "owners", $ns)
    $OwnersElement.InnerText = $ModuleData.Author
    $null = $MetaDataElement.AppendChild($OwnersElement)

    $ProjectURLElement = $doc.CreateNode("element", "projectUrl", $ns)
    $ProjectURLElement.InnerText = $ModuleData.PrivateData.PSData.ProjectUri
    $null = $MetaDataElement.AppendChild($ProjectURLElement)

    $requireLicenseAcceptanceElement = $doc.CreateNode("element", "requireLicenseAcceptance", $ns)
    $requireLicenseAcceptanceElement.InnerText = $false.ToString().ToLower()
    $null = $MetaDataElement.AppendChild($requireLicenseAcceptanceElement)

    $descriptionElement = $doc.CreateNode("element", "description", $ns)
    $descriptionElement.InnerText = $ModuleData.description
    $null = $MetaDataElement.AppendChild($descriptionElement)

    $summaryElement = $doc.CreateNode("element", "summary", $ns)
    $summaryElement.InnerText = $ModuleData.Description
    $null = $MetaDataElement.AppendChild($summaryElement)

    $tagsElement = $doc.CreateNode("element", "tags", $ns)
    $tagsElement.InnerText = $ModuleData.PrivateData.PSData.Tags
    $null = $MetaDataElement.AppendChild($tagsElement)

    $languageElement = $doc.CreateNode("element", "language", $ns)
    $languageElement.InnerText = "en-US"
    $null = $MetaDataElement.AppendChild($languageElement)

    $null = $PackageElement.AppendChild($MetaDataElement)

    $filelistElement = $doc.CreateNode("element", "files", $ns)

    $ModuleData.FileList | ForEach-Object -Process {
        $fileElement = $doc.CreateNode("element", "file", $ns)
        $xmlSrc = $doc.CreateAttribute('src')
        $xmlSrc.Value = (Join-Path $BuildOutput $_)
        $xmlTarget = $doc.CreateAttribute('target')
        $xmlTarget.Value = $_
        $null = $fileElement.Attributes.Append($xmlSrc)
        $null = $fileElement.Attributes.Append($xmlTarget)

        $null = $filelistElement.AppendChild($fileElement)
    }

    $null = $PackageElement.AppendChild($filelistElement)
    $null = $Doc.AppendChild($PackageElement)

    $Doc.Save($outputs)
}
