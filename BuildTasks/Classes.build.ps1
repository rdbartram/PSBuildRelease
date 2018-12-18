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
        @(
            @{file = "attributes.psm1"; filter = "*attribute.psm1"},
            @{ file = "$ProjectName-Classes.psm1"; filter = "*.psm1"; exclude = "*attribute.psm1"; DependantModules = @(".\attributes.psm1") }
        ) | ForEach-Object -Process {

            $ClassScript = @()
            $_["DependantModules"] | Where-Object -FilterScript {
                $null -ne $_ -and (Test-Path $_)
            } | ForEach-Object -Process {
                $ClassScript += "using module $_"
            }

            $i = 0
            # Gather all classes
            $ClassesToImport = Get-ChildItem $ProjectPath\Classes -filter $_["Filter"] -Exclude $_["Exclude"] -Recurse

            # Limit to 10 loops in case of infinite nested classes
            while ($ClassesToImport -ne $null -and $i++ -lt 10) {
                $ClassesToImport | Select-Object -ExpandProperty Fullname -PipelineVariable Path | ForEach-Object -Process {
                    try {
                        # Remove usings and test class can be imported. In failure, catch will be called
                        $ParsedClassFile = ((Get-Content $Path) -notmatch '^using module \.*.\\') -join '
'
                        . ([scriptblock]::create($ParsedClassFile))

                        # Add class content to output variable and remove class from ClassesToImport
                        $ClassScript += $ParsedClassFile
                        $ClassesToImport = $ClassesToImport | Where-Object { $_.fullname -ne $Path }
                    } catch {}
                }
            }

            # if while loop looped too many times, then fail. Maybe nesting issue in classes
            if ($i -eq 11) {
                throw "Class compilation failed"
            }

            # Write compiled classes to output file
            if ($ClassScript.count -ne 0) {
                New-Item (Join-Path $BuildOutput $_["File"]) -Force | Out-Null
                $ClassScript | Set-Content (Join-Path $BuildOutput $_["File"]) -Force
            }
        }
    }
}
