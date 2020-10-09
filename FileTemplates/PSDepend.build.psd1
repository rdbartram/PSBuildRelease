@{
    PSDependOptions    = @{
        Target    = '$DependencyFolder\Dependencies'
        AddToPath = $true
    }

    pester             = 'latest'
    invokebuild        = 'latest'
    BuildHelpers       = 'latest'
    Configuration      = 'latest'
    PowerShellProTools = 'latest'

    BuildFolder        = @{
        DependencyType = 'Command'
        Source         = 'Remove-Item .\.build -Force -Recurse -confirm:$false -ErrorAction SilentlyContinue; New-Item -Type Directory -Path .build -Force | Out-Null; New-Item -Type Directory -Path Dependencies -Force | Out-Null'
    }
    BR                 = @{
        Name      = 'https://github.com/rdbartram/PSBuildRelease'
        Version   = 'master'
        DependsOn = 'BuildFolder'
    }
    ExtractFolder      = @{
        DependencyType = 'Command'
        Source         = 'gci Dependencies\PSBuildRelease\BuildTasks | % {move-item $_.fullname .\.build -force}; sleep 1; remove-item .\Dependencies\PSBuildRelease -Force -Recurse'
        DependsOn      = 'BR'
    }
}
