<#
.SYNOPSIS
    DHCP Enterprise Auditor

.DESCRIPTION
    Iterates through a list of DHCP servers to collect detailed scope metrics, 
    including lease duration, DNS settings, and utilization statistics. 
    Uses PowerShell Background Jobs to process up to 10 servers simultaneously 
    for performance.

.CHANGELOG
    v1.0 - Initial single-server script: Local scope collection and CSV export.
    v2.4 - Major Refactor: 
           - Added multi-threading support via Start-Job for enterprise scale.
           - Added support for external server list file ($ServerListPath).
           - Added Write-Progress tracking and job monitoring.
           - Implemented robust Error Handling (try/catch) for offline servers.
           - Normalized PSCustomObject properties to ensure CSV column consistency.
           - Added fallback for DNS Server options (Scope / Global Level)
           - Fixed AutoStateSwitchover variable to ensure values are returned correctly
           - Fixed Failovermode variable and 

.NOTES
    Author:  James Romeo Gaspar
    Date:    February 4, 2026
    Revision: 2.4 (Original script 1.0 derived from Arnold Kim)
#>

$ServerListPath = "C:\Temp\DCHPServerList.txt"
$ReportPath     = "C:\Temp\DHCP_Full_Enterprise_Report_$(Get-Date -Format 'yyyy-MM-dd_HHmm').csv"
$MaxThreads     = 10

if (-not (Test-Path $ServerListPath)) {
    Write-Host "Error: Server list not found at $ServerListPath" -ForegroundColor Red
    return
}

$ServerList = Get-Content $ServerListPath
$TotalServers = $ServerList.Count
$Counter = 0

Write-Host "Starting detailed scan of $TotalServers servers..." -ForegroundColor Cyan

foreach ($Server in $ServerList) {
    $Counter++
    
    while ((Get-Job -State Running).Count -ge $MaxThreads) {
        Start-Sleep -Milliseconds 500
    }

    Write-Progress -Activity "Dispatching DHCP Jobs" `
                   -Status "Starting job for: $Server" `
                   -PercentComplete (($Counter / $TotalServers) * 100)

    Start-Job -Name "DHCP_$Server" -ScriptBlock {
        param($S) 
        try {
            Import-Module DhcpServer -ErrorAction Stop
            
            $Scopes = Get-DhcpServerv4Scope -ComputerName $S -ErrorAction Stop
            $ServerFailover = Get-DhcpServerv4Failover -ComputerName $S -ErrorAction SilentlyContinue

            $GlobalDns = Get-DhcpServerv4OptionValue -ComputerName $S -ErrorAction SilentlyContinue | Where-Object { $_.OptionId -eq 6 }

            $ScopeData = foreach ($Scope in $Scopes) {

                $Stats = Get-DhcpServerv4ScopeStatistics -ComputerName $S -ScopeId $Scope.ScopeId
                $Total = $Stats.InUse + $Stats.Free
                $PercentUsed = if ($Total -gt 0) { [math]::Round(($Stats.InUse / $Total) * 100, 2) } else { 0 }

                $DnsOption = Get-DhcpServerv4OptionValue -ComputerName $S -ScopeId $Scope.ScopeId -ErrorAction SilentlyContinue | Where-Object { $_.OptionId -eq 6 }
                $DnsToUse = if ($DnsOption.Value) { $DnsOption } else { $GlobalDns }

                $FailoverInfo = $null
                if ($ServerFailover) {
                    $FailoverInfo = $ServerFailover | Where-Object { $Scope.ScopeId -in $_.ScopeId }
                }

                [PSCustomObject]@{
                    Server              = $S
                    ScopeId             = $Scope.ScopeId
                    ScopeName           = $Scope.Name
                    LeaseDuration       = $Scope.LeaseDuration
                    DNSServers          = if ($DnsToUse.Value) { $DnsToUse.Value -join "; " } else { "None Defined" }
                    FailoverMode        = if ($FailoverInfo.Mode) { $FailoverInfo.Mode -join "; " } else { "Standalone" }
                    AutoStateSwitchover = if ($FailoverInfo.AutoStateSwitchoverInterval) { 
                                              $FailoverInfo.AutoStateSwitchoverInterval -join "; " 
                                          } else { 
                                              "Disabled" 
                                          }
                    TotalAddresses      = $Total
                    AddressesInUse      = $Stats.InUse
                    PercentUsed         = "$PercentUsed%"
                    Status              = if ($PercentUsed -ge 80) { "CRITICAL" } else { "Healthy" }
                }
            }
            return $ScopeData
        }
        catch {
            return [PSCustomObject]@{ 
                Server              = $S
                ScopeId             = "ERROR"
                ScopeName           = "Connection Failed"
                LeaseDuration       = $null
                DNSServers          = $null
                FailoverMode        = $null
                AutoStateSwitchover = $null
                TotalAddresses      = 0
                AddressesInUse      = 0
                PercentUsed         = "N/A"
                Status              = "Offline ($($_.Exception.Message))"
            }
        }

    } -ArgumentList $Server
}

while ((Get-Job -State Running).Count -gt 0) {
    $Running = (Get-Job -State Running).Count
    $Completed = (Get-Job -State Completed).Count
    
    Write-Progress -Activity "Monitoring Background Jobs" `
                   -Status "Completed: $Completed | Running: $Running" `
                   -PercentComplete (($Completed / $TotalServers) * 100)
    
    Start-Sleep -Seconds 1
}

Write-Progress -Activity "Monitoring Background Jobs" -Completed

Write-Host "Collecting data and saving report..." -ForegroundColor Cyan

$FullResults = Get-Job | Receive-Job | Where-Object { $_.Server -ne $null }
Get-Job | Remove-Job

$FullResults | Export-Csv -Path $ReportPath -NoTypeInformation -Encoding utf8

Write-Host "Done! Detailed report saved to $ReportPath" -ForegroundColor Green
