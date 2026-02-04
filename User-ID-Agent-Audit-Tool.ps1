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
    Date: February 4, 2026

.CHANGELOG
    v1.0 - Original version from Arnold Kim
    v2.9 - Current version (Refactored):
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

#>

$ServerListPath = "C:\Temp\ServersList.txt"
$OutputCsvPath  = "C:\Temp\UserID_Report_$(Get-Date -Format 'yyyy-MM-dd_HHmm').csv"

$ServiceName = "UserIDService"
$BaseDir     = "C$\Program Files (x86)\Palo Alto Networks\User-ID Agent"
$ConfigPath  = "$BaseDir\UserIDAgentConfig.xml"
$LogPath     = "$BaseDir\UaDebug.log"

if (-not (Test-Path $ServerListPath)) {
    Write-Error "Input file not found at $ServerListPath"
    return
}

$Servers = Get-Content $ServerListPath
$Results = ForEach ($Server in $Servers) {
    Write-Host "--- Auditing: $Server ---" -ForegroundColor Cyan
    
    $Status = "Unknown"
    $ConnectedServers = "None Found"
    $ConnectedDevices = "None Found"
    $AuditNote = "Processed"

    if (-not (Test-Connection -ComputerName $Server -Count 1 -Quiet)) {
        $Status = "Offline"
    } 
    else {
        try {
            $Svc = Get-CimInstance -ComputerName $Server -ClassName Win32_Service -Filter "Name='$ServiceName'" -ErrorAction SilentlyContinue
            $Status = if ($Svc) { $Svc.State } else { "Service Not Found" }

            $XmlPath = "\\$Server\$ConfigPath"
            if (Test-Path $XmlPath) {
                [xml]$xml = Get-Content $XmlPath
                $SrvNodes = $xml.SelectNodes("//server-entry")
                if ($SrvNodes) {
                    $ConnectedServers = ($SrvNodes | Where-Object { $_.address -ne "127.0.0.1" } | ForEach-Object { 
                        "$($_.name) ($($_.address))" 
                    }) -join " | "
                }
            }

            $UNCLogPath = "\\$Server\$LogPath"
            if (Test-Path $UNCLogPath) {
                $ActiveSessions = @{} 
                $ThreadMap      = @{} 
                
                $LogContent = Get-Content $UNCLogPath
                foreach ($RawLine in $LogContent) {
                    $Line = $RawLine.Trim()

                    if ($Line -match "User-ID Agent service started") {
                        $ActiveSessions.Clear(); $ThreadMap.Clear(); continue 
                    }

                    if ($Line -match "Device thread (\d+) with ([\d\.]+ : \d+) is started") {
                        $TID = $Matches[1]; $Session = $Matches[2]
                        if ($Session -notmatch "^127\.0\.0\.1") {
                            if ($ThreadMap.ContainsKey($TID)) { $ActiveSessions.Remove($ThreadMap[$TID]) }
                            $ActiveSessions[$Session] = $TID
                            $ThreadMap[$TID] = $Session
                        }
                    }

                    if ($Line -match "Connection ([\d\.]+ : \d+) closed") {
                        $Session = $Matches[1]
                        if ($ActiveSessions.ContainsKey($Session)) {
                            $ThreadMap.Remove($ActiveSessions[$Session])
                            $ActiveSessions.Remove($Session)
                        }
                    }

                    if ($Line -match "Device thread (\d+) exit") {
                        $TID = $Matches[1]
                        if ($ThreadMap.ContainsKey($TID)) {
                            $ActiveSessions.Remove($ThreadMap[$TID])
                            $ThreadMap.Remove($TID)
                        }
                    }
                }
                
                if ($ActiveSessions.Count -gt 0) {
                    $ConnectedDevices = ($ActiveSessions.Keys | Sort-Object) -join " | "
                }
            }
        } 
        catch {
            $Status = "Access Denied"
            $AuditNote = $_.Exception.Message
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

$Results | Export-Csv -Path $OutputCsvPath -NoTypeInformation
Write-Host "`nFinal Audit Complete. Results saved to: $OutputCsvPath" -ForegroundColor Green
