Describe 'Public command parameter metadata' {
    It 'does not expose WebSession as a positional parameter' {
        $publicFiles = Get-ChildItem -Path (Join-Path $PSScriptRoot '..\..\..\POSH-Oceanstor\Public') -Filter '*.ps1'
        $offenders = foreach ($file in $publicFiles) {
            $tokens = $null
            $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref] $tokens, [ref] $errors)

            foreach ($parameter in $ast.FindAll({
                        param($node)
                        $node -is [System.Management.Automation.Language.ParameterAst] -and
                        $node.Name.VariablePath.UserPath -eq 'WebSession'
                    }, $true)) {
                foreach ($attribute in $parameter.Attributes) {
                    if ($attribute.TypeName.FullName -ne 'Parameter') {
                        continue
                    }

                    foreach ($argument in $attribute.NamedArguments) {
                        if ($argument.ArgumentName -eq 'Position') {
                            '{0}:{1}' -f $file.Name, $parameter.Extent.StartLineNumber
                        }
                    }
                }
            }
        }

        $offenders | Should -BeNullOrEmpty
    }
}
