#Requires -Version 7.0
BeforeAll {
    $ModulePath = Join-Path -Path ${PSScriptRoot} -ChildPath '..' -AdditionalChildPath 'src', 'modules', 'Helpers.psm1'
    Import-Module -Name (Resolve-Path ${ModulePath}) -Force
}

Describe 'Write-StatusMessage' {
    It 'should not throw for valid types' {
        { Write-StatusMessage -Message 'Test' -Type 'Info' } | Should -Not -Throw
    }
}
