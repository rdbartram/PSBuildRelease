# PSBuildRelease

Generic InvokeBuild tasks used during PowerShell module development.

- [PSBuildRelease](#psbuildrelease)
  - [Installation](#installation)
    - [Prerequisites](#prerequisites)
    - [Module Structure](#module-structure)
  - [Usage](#usage)
    - [Azure DevOps](#azure-devops)
    - [Locally](#locally)
  - [Contributing](#contributing)

## Installation

To properly make use of these task you need to make sure your code follows a few guidelines.

### Prerequisites

- [PSDepend](https://github.com/RamblingCookieMonster/PSDepend)
- [Pester](https://github.com/pester/Pester)
- [InvokeBuild](https://github.com/nightroman/Invoke-Build)
- [BuildQualityChecks (Azure Devops Task)](https://marketplace.visualstudio.com/items?itemName=mspremier.BuildQualityChecks)
- [GitVersion (Azure Devops Task)](https://marketplace.visualstudio.com/items?itemName=gittools.gitversion)
- [BuildHelpers](https://github.com/RamblingCookieMonster/BuildHelpers)
- [GitVersion](https://github.com/GitTools/GitVersion) (Optional)
- [PowerShell Core](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-windows?view=powershell-6) (For building locally)

### Module Structure

```powershell
+── src
│   +── classes  (Optional)
│   │   +── *.psm1
│   +── private (Optional)
│   │   +── *.ps1
│   +── public (Optional)
│   │   +── *.ps1
+── tests (Optional)
+── Manifest.json
+── azure-pipelines.yml
+── GitVersion.yml (Optional)
+── .build.ps1
+── PSDepend.build.psd1
```

Check the template files contained in this repository for help.

## Usage

### Azure DevOps

After configuring according to [Installation](#Installation) run your Azure Pipelines build process.

### Locally

To build locally you will require PowerShell Core. This has no impact on the actual usage of the module or the tests, but it required for things such as semanticversioning class, New-ModuleManifest improvements etc.

```powershell
Invoke-Build -Tasks CreateModuleManifest, DownloadDependentModules -ResolveDependency
```

Once the module is built, you can run the tests in either PowerShell Core or WinPS as necessary.

```powershell
Invoke-Build -Tasks Test
```

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.
