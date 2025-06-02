<#
    .SYNOPSIS
        Export enabled AD users whose sAMAccountName matches specific format + “.suffix”, including their group memberships.

    .DESCRIPTION
        Queries Active Directory for enabled users, filters on sAMAccountName of the form:
            [A-Za-z]{2}\d{7}\.<suffix>
        Retrieves each user’s security groups, then exports SamAccountName, BaseName, Suffix, Enabled flag, and Groups to a dated CSV file.

    .NOTES
        File will be named “AD_Accounts_WithGroups_yyyyMMdd.csv” in C:\Temp.

    .AUTHOR
        James Romeo Gaspar
        30 May 2025
#>

$today      = Get-Date -Format yyyyMMdd
$exportPath = "C:\Temp\AD_Accounts_WithGroups_$today.csv"
$users = Get-ADUser -Filter {Enabled -eq $True} -Properties sAMAccountName, Enabled
$results = foreach ($u in $users) {
    $name    = $u.sAMAccountName
    $enabled = $u.Enabled

    if ($name -match '^(?<base>[A-Za-z]{2}\d{7})\.(?<suffix>.+)$') {
        $groups = (
            Get-ADPrincipalGroupMembership -Identity $u |
            Select-Object -ExpandProperty Name |
            Sort-Object
        ) -join ';'

        [PSCustomObject]@{
            SamAccountName = $name
            BaseName       = $Matches['base']
            Suffix         = $Matches['suffix']
            Enabled        = $enabled
            Groups         = $groups
        }
    }
}

$results |
  Select-Object SamAccountName, BaseName, Suffix, Enabled, Groups |
  Export-Csv -Path $exportPath -NoTypeInformation -Encoding UTF8

Write-Host "Exported $($results.Count) enabled accounts (with groups) to $exportPath"
