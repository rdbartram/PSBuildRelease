param (
    [parameter()]
    [io.DirectoryInfo]
    $ProjectPath = (property ProjectPath $BuildRoot),

    [parameter()]
    [string]
    $ProjectName = (property ProjectName $ProjectName),

    [string]
    $BuildOutput = (property BuildOutput 'C:\BuildOutput')
)

task CompileClasses @{
    if      = {Test-Path $ProjectPath\classes\}
    inputs  = {
        Get-Item $ProjectPath\classes\* -ErrorAction SilentlyContinue
    }
    outputs = {
        "$BuildOutput\$ProjectName-Classes.psm1"
    }
    Jobs    = {
        $files = @(
            @{file = "attributes.psm1"; filter = "*-attribute.psm1"},
            @{file = "$ProjectName-Classes.psm1"; filter = "*.psm1"; exclude = "*-attribute.psm1"; DependantModules = @(".\attributes.psm1") }
        )

        foreach ($file in $files) {

            $classScript = @()
            $dependentModules = $file["DependantModules"] | Where-Object -FilterScript {
                $null -ne $_ -and (Test-Path $_)
            }

            foreach ($dependentModule in $dependentModules) {
                $classScript += "using module $dependentModule"
            }

            $i = 0
            # Gather all classes
            $classesToImport = Get-ChildItem $ProjectPath\classes -filter $file["Filter"] -Exclude $file["Exclude"] -Recurse

            $usings = @()
            $classPaths = $classesToImport.Fullname

            # Loop each class and remove usings whilst cataloging them to be added at the top of compiled module
            foreach ($classPath in $classPaths) {
                $path = $classPath
                $usingRaws = (Get-Content $path) -match 'using (module)|(namespace)'

                foreach ($usingRaw in $usingRaws) {
                    # matching is as following
                    #
                    # if using is already in cataloged list, ignore
                    # if using resolves to a module outside of the current project then add to catalog
                    # if a using resolves to a binary local to module then add to catalog
                    # if a namespace then add to catalog
                    if ($usings -contains $usingRaw) {
                    } elseif ($usingRaw -match 'using module [^.]') {
                        Add-Content -Path $classPath -Value $usingRaw -Force
                    } elseif (
                        $usingRaw -match 'using module (\.{0,2}\\.*binaries)\\(.+)' -and
                        (Resolve-Path (Join-Path $ProjectPath "binaries")).ToString() -eq (Resolve-Path (Join-Path (Split-Path $path -Parent) $matches[1]).ToString())
                    ) {
                        Add-Content -Path $classPath -Value "using module .\Binaries\$($matches[2])" -Force
                    } elseif ($usingRaw -match 'using namespace') {
                        Add-Content -Path $classPath -Value $usingRaw -Force
                    }
                    $usings += $usingRaw
                }
            }

            . ([scriptblock]::create($ClassScript))

            # Limit to 10 loops in case of infinite nested classes
            while ($classesToImport -ne $null -and $i++ -lt 10) {
                $classPaths = $classesToImport.Fullname

                foreach ($classPath in $classPaths) {
                    try {
                        # Remove usings and test class can be imported. In failure, catch will be called
                        $parsedClassFile = ((Get-Content $classPath) -notmatch 'using (module)|(namespace)') -join [System.Environment]::newline
                        . ([scriptblock]::create($parsedClassFile))

                        # Add class content to output variable and remove class from classesToImport
                        $classScript += $parsedClassFile
                        $classesToImport = $classesToImport | Where-Object { $classPath -ne $classPath }
                    } catch {}
                }
            }

            # if while loop looped too many times, then fail. Maybe nesting issue in classes
            if ($i -eq 11) {
                throw "Class compilation failed"
            }

            # Write compiled classes to output file
            if ($classScript.count -ne 0) {
                New-Item (Join-Path $BuildOutput $file["File"]) -Force | Out-Null
                $classScript | Set-Content (Join-Path $BuildOutput $file["File"]) -Force
            }
        }
    }
}
