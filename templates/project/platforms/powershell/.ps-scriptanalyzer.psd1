@{
    Rules = @{
        PSAvoidUsingWriteHost = @{ Enable = $false }
    }
    ExcludeRules = @()
    IncludeDefaultRules = $true
    Severity = @('Error', 'Warning')
}
