Import-Module ActiveDirectory
$csvPath = "C:\Temp\AD-AllOU-List.csv"
$ous = Get-ADOrganizationalUnit -Filter * -Properties CanonicalName
$ouData = @()
foreach ($ou in $ous) {
    $ouData += [PSCustomObject]@{
        Name = $ou.Name
        CanonicalName = $ou.CanonicalName
        Description = $ou.Description
        DistinguishedName = $ou.DistinguishedName
        Path = $ou.DistinguishedName.Replace("OU=", "").Replace(",DC=", "/").Substring(3)
    }
}
$ouData | Export-Csv -Path $csvPath -NoTypeInformation
