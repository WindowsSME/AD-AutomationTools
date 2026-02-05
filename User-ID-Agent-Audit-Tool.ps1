<#
.SYNOPSIS
    Palo Alto User-ID Agent Audit and Reporting Tool.

.DESCRIPTION
    This script performs a remote audit of multiple Palo Alto User-ID Agents. 
    It verifies the service status, extracts the list of monitored Domain Controllers from 
    the XML configuration, and identifies active firewall connections by parsing the 
    Agent's debug logs. Results are exported to a timestamped CSV.

.NOTES
    Author: James Romeo Gaspar
    Date: February 5, 2026

.CHANGELOG
    v1.0 - Original version from Arnold Kim
    v3.2.1 - Current version (Refactored):
        - Added Remote Support: Now iterates through a list of servers via '$ServerListPath'.
        - Removed CLI Dependency: Switched to direct XML parsing of 'UserIDAgentConfig.xml' 
          because 'ua_cli.exe' was missing or inaccessible in many environments.
        - Log-Based Discovery: Implemented 'UaDebug.log' parsing to identify 'Connected 
          Devices' (Firewalls) using regex to find active connection events.
        - Added Resilience: Included ICMP Ping tests and Error/Access Denied handling.
        - Reporting: Added automated CSV export with unique timestamps.
        - Switched to XML parsing for 'Connected Devices'
        - Added 127.0.0.1 filtering.
        - Integrated '.Trim()' on log lines, Removed '^' anchors from Log RegEx 
        - Implemented Thread-Aware state tracking (matches GUI)
        - Added timeout logic for unreachable servers
        - Added session cleanup
        - Fixed unsupported parameters

#>

$ServerListPath = "C:\Temp\UserIDServerList.txt"
$OutputCsvPath  = "C:\Temp\UserID_Report_$(Get-Date -Format 'yyyy-MM-dd_HHmm').csv"
$LogFile        = "C:\Temp\Audit_Session_Log_$(Get-Date -Format 'yyyy-MM-dd_HHmm').txt"

$ServiceName = "UserIDService"
$BaseDir     = "C$\Program Files (x86)\Palo Alto Networks\User-ID Agent"
$ConfigPath  = "$BaseDir\UserIDAgentConfig.xml"
$LogPath     = "$BaseDir\UaDebug.log"

Start-Transcript -Path $LogFile -Append

$PSSessionOption = New-PSSessionOption -MaxConnectionRetryCount 0

if (-not (Test-Path $ServerListPath)) {
    Write-Error "Input file not found at $ServerListPath"
    Stop-Transcript
    return
}

$Servers = Get-Content $ServerListPath
$TotalServers = $Servers.Count
$Counter = 0

$Results = ForEach ($Server in $Servers) {
    $Counter++
    Write-Host "`n[$Counter/$TotalServers] --- Auditing: $Server ---" -ForegroundColor Cyan
    
    $Status = "Unknown"
    $ConnectedServers = "None Found"
    $ConnectedDevices = "None Found"
    $AuditNote = "Processed Successfully"

    if (-not (Test-Connection -ComputerName $Server -Count 1 -Quiet)) {
        Write-Warning "Ping failed for $Server"
        $Status = "Offline"
        $AuditNote = "Ping Failed"
    } 
    else {
        $CimSession = $null
        try {

            $Option = New-CimSessionOption -Protocol Dcom
            $CimSession = New-CimSession -ComputerName $Server -SessionOption $Option -ErrorAction Stop
            
            $Svc = Get-CimInstance -CimSession $CimSession -ClassName Win32_Service -Filter "Name='$ServiceName'" -OperationTimeoutSec 10 -ErrorAction Stop
            $Status = if ($Svc) { $Svc.State } else { "Service Not Found" }
            
            $XmlPath = "\\$Server\$ConfigPath"
            if (Test-Path $XmlPath) {
                [xml]$xml = Get-Content $XmlPath -ErrorAction SilentlyContinue
                $SrvNodes = $xml.SelectNodes("//server-entry")
                if ($SrvNodes) {
                    $ConnectedServers = ($SrvNodes | Where-Object { $_.address -ne "127.0.0.1" } | ForEach-Object { 
                        "$($_.name) ($($_.address))" 
                    }) -join " | "
                }
            }

            $UNCLogPath = "\\$Server\$LogPath"
            if (Test-Path $UNCLogPath) {
                $LogContent = Get-Content $UNCLogPath -Tail 1000 -ErrorAction SilentlyContinue
                if ($LogContent) {
                    $ActiveSessions = @{}; $ThreadMap = @{}
                    foreach ($Line in $LogContent) {
                        if ($Line -match "Device thread (\d+) with ([\d\.]+ : \d+) is started") {
                            $ActiveSessions[$Matches[2]] = $Matches[1]
                            $ThreadMap[$Matches[1]] = $Matches[2]
                        }
                        if ($Line -match "Connection ([\d\.]+ : \d+) closed") {
                            $Session = $Matches[1]
                            if ($ActiveSessions.ContainsKey($Session)) {
                                $ThreadMap.Remove($ActiveSessions[$Session])
                                $ActiveSessions.Remove($Session)
                            }
                        }
                    }
                    if ($ActiveSessions.Count -gt 0) { $ConnectedDevices = ($ActiveSessions.Keys | Sort-Object) -join " | " }
                }
            }
        } 
        catch {
            $Status = "Server Unreachable"
            $AuditNote = "Connection Timeout: $($_.Exception.Message)"
            Write-Host "Failed. Skipping..." -ForegroundColor Yellow
        }
        finally {
            if ($null -ne $CimSession) { 
                $CimSession | Remove-CimSession 
            }
            [System.GC]::Collect()
        }
    }

    [PSCustomObject]@{
        Timestamp        = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        ServerName       = $Server
        ServiceStatus    = $Status
        ConnectedServers = $ConnectedServers
        ConnectedDevices = $ConnectedDevices
        AuditNote        = $AuditNote
    }
}

Write-Host "`n"
Write-Host ("=" * 40) -ForegroundColor White
Write-Host "         AUDIT SUMMARY" -ForegroundColor White
Write-Host ("=" * 40) -ForegroundColor White
$Results | Group-Object ServiceStatus | Select-Object @{Name='Status';Expression={$_.Name}}, Count | Format-Table -AutoSize
Write-Host ("=" * 40) -ForegroundColor White

$Results | Export-Csv -Path $OutputCsvPath -NoTypeInformation
Write-Host "`nFinal Audit Complete." -ForegroundColor Green
Write-Host "Report: $OutputCsvPath"
Write-Host "Full Session Log: $LogFile"

Stop-Transcript
