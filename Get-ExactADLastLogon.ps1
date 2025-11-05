<#
.SYNOPSIS
Get-ExactADLastLogon.ps1
Generates an exact LastLogon report for a list of AD users by querying all reachable domain controllers.

.DESCRIPTION
Reads user sAMAccountNames from C:\Temp\ADUsersLogonTime.txt, checks each reachable DC,
retrieves the raw lastLogon attribute, converts it to DateTime, and selects the most recent
value per user. Progress is shown for users and DCs. Results are exported to:
C:\Temp\LastLogon-Exact.csv

.REQUIREMENTS
- Input file at C:\Temp\ADUsersLogonTime.txt (one user per line)

.OUTPUTS
CSV: User, LastLogon, SourceDC

.PARAMETER (implicit)
Input users are taken from C:\Temp\ADUsersLogonTime.txt

.NOTES
- lastLogon is non-replicated; the script queries each DC to find the true latest value.
- Unreachable DCs are skipped; errors are written succinctly to the host.
- Update $csvPath to change the export location if needed.

.VERSION
2.0

.AUTHOR
James Romeo Gaspar
November 6, 2025

#> 

Import-Module ActiveDirectory

$users = Get-Content C:\Temp\ADUsersLogonTime.txt
$dcs = Get-ADDomainController -Filter * |
       Where-Object { Test-Connection -ComputerName $_.HostName -Count 1 -Quiet -ErrorAction SilentlyContinue } |
       Select-Object -ExpandProperty HostName

$report  = @()
$uCount  = $users.Count
$dcCount = $dcs.Count

for ($ui = 0; $ui -lt $uCount; $ui++) {
    $u = $users[$ui]

    $userPct = [int](($ui + 1) / $uCount * 100)
    Write-Progress -Id 1 -Activity "Processing users ($($ui+1)/$uCount)" `
                   -Status "User: $u" -PercentComplete $userPct

    $perDc = @()

    for ($di = 0; $di -lt $dcCount; $di++) {
        $dc = $dcs[$di]

        $dcPct = [int](($di + 1) / $dcCount * 100)
        Write-Progress -Id 2 -ParentId 1 -Activity "Querying DCs ($($di+1)/$dcCount)" `
                       -Status "User: $u  |  DC: $dc" -PercentComplete $dcPct

        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $($di + 1)/$dcCount  $u on $dc"

        try {
            $obj = Get-ADUser -Identity $u -Server $dc -Properties lastLogon -ErrorAction Stop |
                   Select-Object @{n='User';e={$u}},
                                 @{n='DC';e={$dc}},
                                 @{n='LastLogon';e={ if ($_.lastLogon -gt 0) { [DateTime]::FromFileTime($_.lastLogon) } else { $null } }}
            if ($obj) { $perDc += $obj }
        } catch {
            # Log the error briefly; keep progress clean
            Write-Host ("[{0:HH:mm:ss}] ERROR  {1} on {2} : {3}" -f (Get-Date), $u, $dc, $_.Exception.Message)
            continue
        }
    }

    Write-Progress -Id 2 -ParentId 1 -Activity "Querying DCs" -Completed

    if ($perDc) {
        $best = $perDc | Sort-Object LastLogon -Descending | Select-Object -First 1
        $report += [PSCustomObject]@{
            User      = $u
            LastLogon = $best.LastLogon
            SourceDC  = $best.DC
        }
    } else {
        $report += [PSCustomObject]@{
            User      = $u
            LastLogon = $null
            SourceDC  = $null
        }
    }
}

Write-Progress -Id 1 -Activity "Processing users" -Completed

$csvPath = "C:\Temp\LastLogon-Exact.csv"
$report | Export-Csv $csvPath -NoTypeInformation
Write-Host ("[{0:HH:mm:ss}] DONE. Wrote report to {1}" -f (Get-Date), $csvPath)
Write-Host "Processed $uCount users across $dcCount DCs"
